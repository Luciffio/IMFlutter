import 'dart:math';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'connecting_line.dart';
import 'entry_bubble.dart';
import 'image_bubble.dart';
import 'reply_bubble.dart';
import 'typing_indicator.dart';

// ── Per-message animation state ────────────────────────────────────────────

class _EntryState {
  final Message message;
  final int position;
  bool disposed = false;

  // Current (possibly shifted) line coordinates for the TOP of the connecting line.
  Offset lineLeft;
  Offset lineRight;

  // Frozen snapshot of the BOTTOM line coordinates — set once when lineCtrl starts.
  // Using these (instead of next.lineLeft) prevents the line from jumping when
  // the next message later receives its own horizontal shift.
  Offset? frozenBottomLeft;
  Offset? frozenBottomRight;
  bool frozenNextIsRen = false;

  late final AnimationController avatarBgCtrl;
  late final AnimationController avatarFgCtrl;
  late final AnimationController msgHCtrl;
  late final AnimationController msgVCtrl;
  late final AnimationController msgAlphaCtrl;
  late final AnimationController lineCtrl;

  late final Animation<double> avatarBgScale;
  late final Animation<double> avatarFgScale;
  late final Animation<double> msgHScale;
  late final Animation<double> msgVScale;
  late final Animation<double> msgAlpha;
  late final Animation<double> lineProgress;

  _EntryState({
    required this.message,
    required this.position,
    required this.lineLeft,
    required this.lineRight,
  });

  bool get hasLine => frozenBottomLeft != null;

  void dispose() {
    disposed = true;
    avatarBgCtrl.dispose();
    avatarFgCtrl.dispose();
    msgHCtrl.dispose();
    msgVCtrl.dispose();
    msgAlphaCtrl.dispose();
    lineCtrl.dispose();
  }
}

// ── TranscriptState ────────────────────────────────────────────────────────

class TranscriptState extends ChangeNotifier {
  final TickerProvider vsync;
  final List<Message> _messages;
  final Random _rng = Random();

  final List<_EntryState> _entries = [];
  List<_EntryState> get entries => List.unmodifiable(_entries);

  int _messageIndex = 0;

  TranscriptState({required this.vsync, required List<Message> messages})
      : _messages = messages;

  // ── Public API ────────────────────────────────────────────────────────────

  /// Advance to the next pre-loaded demo message.
  /// Loops back to the start when all messages have been shown.
  void advance() {
    if (_messageIndex >= _messages.length) {
      for (final e in _entries) e.dispose();
      _entries.clear();
      _messageIndex = 0;
      notifyListeners();
      return;
    }
    _showMessage(_messages[_messageIndex++]);
  }

  /// Add any message to the transcript immediately (user-sent or incoming
  /// from the backend).  Called by ChatScreen — not tied to the demo sequence.
  void addMessage(Message message) => _showMessage(message);

  // ── Internal ───────────────────────────────────────────────────────────────

  void _showMessage(Message message) {
    final position = _entries.length;

    // Base line coordinates (horizontal shift applied later during finalization)
    final lineWidth =
        kMinLineWidth + _rng.nextDouble() * (kMaxLineWidth - kMinLineWidth);
    final Offset lineLeft, lineRight;
    if (message.sender == Sender.ren) {
      final lx = kRenMessageCenterX - lineWidth / 2;
      lineLeft = Offset(lx, kRenMessageCenterY);
      lineRight = Offset(lx + lineWidth, kRenMessageCenterY);
    } else if (message.isImage) {
      // Line terminates at the visual center of the image frame
      final lx = kImageCenterX - lineWidth / 2;
      lineLeft = Offset(lx, kImageCenterY);
      lineRight = Offset(lx + lineWidth, kImageCenterY);
    } else {
      final lx = kAvatarWidth / 2 - lineWidth / 2;
      lineLeft = Offset(lx, kAvatarHeight / 2);
      lineRight = Offset(lx + lineWidth, kAvatarHeight / 2);
    }

    final state = _EntryState(
      message: message,
      position: position,
      lineLeft: lineLeft,
      lineRight: lineRight,
    );

    // ── Animations ──────────────────────────────────────────────────────

    state.avatarBgCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 300));
    state.avatarBgScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: state.avatarBgCtrl, curve: Curves.easeOutBack),
    );
    state.avatarBgCtrl.forward();

    state.avatarFgCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 150));
    state.avatarFgScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: state.avatarFgCtrl, curve: Curves.easeOutBack),
    );
    Future.delayed(const Duration(milliseconds: 160), () {
      if (!state.disposed) state.avatarFgCtrl.forward();
    });

    state.msgHCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 180));
    state.msgHScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: state.msgHCtrl, curve: Curves.easeOutBack),
    );
    state.msgHCtrl.forward();

    state.msgVCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 180));
    state.msgVScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: state.msgVCtrl, curve: Curves.easeOutBack),
    );
    state.msgVCtrl.forward();

    state.msgAlphaCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 130));
    state.msgAlpha =
        Tween<double>(begin: 0.0, end: 1.0).animate(state.msgAlphaCtrl);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!state.disposed) state.msgAlphaCtrl.forward();
    });

    state.lineCtrl = AnimationController(
        vsync: vsync, duration: const Duration(milliseconds: 180));
    state.lineProgress =
        Tween<double>(begin: 0.0, end: 1.0).animate(state.lineCtrl);

    // ── Finalize PREVIOUS entry ──────────────────────────────────────────
    // Tiny random jitter (±8 dp) for visual variety without forced zigzag.
    // Then FREEZE bottom coords before starting the line animation so later
    // shifts on `state` can't move the already-drawn line.
    if (_entries.isNotEmpty) {
      final prev = _entries.last;
      // Skip jitter for image messages — their line is anchored at a fixed center
      if (prev.message.sender != Sender.ren && !prev.message.isImage) {
        final shift = (_rng.nextDouble() * 16) - 8; // –8 … +8 dp
        prev.lineLeft = prev.lineLeft + Offset(shift, 0);
        prev.lineRight = prev.lineRight + Offset(shift, 0);
      }
      prev.frozenBottomLeft = state.lineLeft;
      prev.frozenBottomRight = state.lineRight;
      prev.frozenNextIsRen = state.message.sender == Sender.ren;
      prev.lineCtrl.forward();
    }

    _entries.add(state);
    notifyListeners();
  }

  @override
  void dispose() {
    for (final e in _entries) e.dispose();
    super.dispose();
  }
}

// ── Transcript widget ──────────────────────────────────────────────────────

class Transcript extends StatefulWidget {
  final TranscriptState state;
  const Transcript({super.key, required this.state});

  @override
  State<Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<Transcript> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onStateChanged);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onStateChanged);
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.state.entries;
    return ListView.separated(
      controller: _scrollCtrl,
      padding: EdgeInsets.only(
        // Clear the ChatHeader (topPad + 72 dp content + 8 dp gap)
        top: MediaQuery.of(context).padding.top + 88,
        // Extra 80 dp so the last item clears the floating InputBar (~70 dp)
        bottom: 180 + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: entries.length + 1, // +1 for TypingIndicator
      separatorBuilder: (_, __) => const SizedBox(height: kEntrySpacing),
      itemBuilder: (context, index) {
        // Stable key keeps TypingIndicator's State alive as the list grows
        if (index == entries.length) {
          return const TypingIndicator(key: ValueKey('typing_indicator'));
        }

        final entry = entries[index];

        return AnimatedBuilder(
          animation: Listenable.merge([
            entry.avatarBgScale,
            entry.avatarFgScale,
            entry.msgHScale,
            entry.msgVScale,
            entry.msgAlpha,
            entry.lineProgress,
          ]),
          builder: (_, __) => _buildItem(entry),
        );
      },
    );
  }

  Widget _buildItem(_EntryState entry) {
    Widget item;
    if (entry.message.sender == Sender.ren) {
      item = ReplyBubble(
        text: entry.message.text,
        messageHorizontalScale: entry.msgHScale.value,
        messageVerticalScale: entry.msgVScale.value,
        messageTextAlpha: entry.msgAlpha.value,
      );
    } else if (entry.message.isImage) {
      item = ImageBubble(
        message: entry.message,
        hScale: entry.msgHScale.value,
        vScale: entry.msgVScale.value,
        alpha: entry.msgAlpha.value,
      );
    } else {
      item = EntryBubble(
        message: entry.message,
        avatarBackgroundScale: entry.avatarBgScale.value,
        avatarForegroundScale: entry.avatarFgScale.value,
        messageHorizontalScale: entry.msgHScale.value,
        messageVerticalScale: entry.msgVScale.value,
        messageTextAlpha: entry.msgAlpha.value,
      );
    }

    // Only draw the connecting line once the next message has arrived and
    // frozen the bottom coordinates.
    if (!entry.hasLine) return item;

    return CustomPaint(
      painter: ConnectingLinePainter(
        currentIsRen: entry.message.sender == Sender.ren,
        currentLineLeft: entry.lineLeft,
        currentLineRight: entry.lineRight,
        nextIsRen: entry.frozenNextIsRen,
        nextLineLeft: entry.frozenBottomLeft!,
        nextLineRight: entry.frozenBottomRight!,
        lineProgress: entry.lineProgress.value,
      ),
      child: item,
    );
  }
}
