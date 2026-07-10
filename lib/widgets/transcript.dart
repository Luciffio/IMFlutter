import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'connecting_line.dart';
import 'entry_bubble.dart';
import 'file_bubble.dart';
import 'image_bubble.dart';
import 'reply_bubble.dart';
import 'sticker_bubble.dart';

// ── Per-message animation state ────────────────────────────────────────────

class _EntryState {
  Message message;
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
  bool frozenNextIsSticker = false;

  // Line style assigned when this entry's connecting line is finalized.
  LineStyle lineStyle = LineStyle.straight;
  double jogOffsetX = 0;
  double jogFraction = 0.5;

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
  List<_EntryState> get _visibleEntries => List.unmodifiable(_entries);

  int _messageIndex = 0;
  bool _isSomeoneTyping = false;
  bool _disposed = false;
  bool _suppressNextAutoScroll = false;
  int _typingRequest = 0;

  bool get isSomeoneTyping => _isSomeoneTyping;

  void setSomeoneTyping(bool isTyping) {
    if (_disposed || _isSomeoneTyping == isTyping) return;
    _typingRequest++;
    _isSomeoneTyping = isTyping;
    notifyListeners();
  }

  String? get oldestMessageId {
    for (final message in _messages) {
      final id = message.id;
      if (id != null && id.isNotEmpty) return id;
    }
    return null;
  }

  TranscriptState({required this.vsync, required List<Message> messages})
    : _messages = List.of(messages);

  // ── Public API ────────────────────────────────────────────────────────────

  /// Advance to the next pre-loaded demo message.
  /// Loops back to the start when all messages have been shown.
  void advance() {
    if (_messageIndex >= _messages.length) {
      for (final e in _entries) {
        e.dispose();
      }
      _entries.clear();
      _messageIndex = 0;
      notifyListeners();
      return;
    }
    _showMessage(_messages[_messageIndex++]);
  }

  void showAll() {
    while (_messageIndex < _messages.length) {
      _showMessage(_messages[_messageIndex++]);
    }
  }

  Future<void> advanceAfterTyping() async {
    if (_isSomeoneTyping || _disposed) return;
    if (_messageIndex >= _messages.length) {
      advance();
      return;
    }

    final request = ++_typingRequest;
    _isSomeoneTyping = true;
    notifyListeners();
    await Future<void>.delayed(const Duration(milliseconds: 1100));
    if (_disposed || request != _typingRequest) return;

    _isSomeoneTyping = false;
    _showMessage(_messages[_messageIndex++]);
  }

  /// Add any message to the transcript immediately (user-sent or incoming
  /// from the backend).  Called by ChatScreen — not tied to the demo sequence.
  void addMessage(Message message) {
    _typingRequest++;
    _isSomeoneTyping = false;
    _messages.add(message);
    _showMessage(message);
  }

  void prependMessages(List<Message> messages) {
    if (messages.isEmpty || _disposed) return;

    final knownIds = _messages.map((message) => message.id).whereType<String>();
    final known = knownIds.toSet();
    final fresh = messages
        .where((message) => message.id == null || !known.contains(message.id))
        .toList();
    if (fresh.isEmpty) return;

    _messages.insertAll(0, fresh);
    _rebuildVisibleEntries();
    _suppressNextAutoScroll = true;
    notifyListeners();
  }

  void replaceMessage(Message replacement) {
    final id = replacement.id;
    if (id == null || _disposed) return;
    final index = _messages.indexWhere((message) => message.id == id);
    if (index < 0) return;
    final previous = _messages[index];
    _messages[index] = replacement;
    final canUpdateInPlace =
        previous.kind == replacement.kind &&
        previous.sender == replacement.sender &&
        previous.text == replacement.text;
    if (canUpdateInPlace) {
      final entryIndex = _entries.indexWhere((entry) => entry.message.id == id);
      if (entryIndex >= 0) {
        _entries[entryIndex].message = replacement;
      }
    } else {
      _rebuildVisibleEntries();
    }
    _suppressNextAutoScroll = true;
    notifyListeners();
  }

  bool takeSuppressNextAutoScroll() {
    final value = _suppressNextAutoScroll;
    _suppressNextAutoScroll = false;
    return value;
  }

  // ── Internal ───────────────────────────────────────────────────────────────

  void _showMessage(
    Message message, {
    bool animate = true,
    bool notify = true,
  }) {
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
      // Line anchors at the top edge of the image bubble (within the transparent
      // topPad area) so the connecting-line shadow remains visible.
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
      vsync: vsync,
      duration: const Duration(milliseconds: 300),
    );
    state.avatarBgScale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: state.avatarBgCtrl, curve: Curves.easeOutBack),
    );
    if (animate) {
      state.avatarBgCtrl.forward();
    } else {
      state.avatarBgCtrl.value = 1.0;
    }

    state.avatarFgCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 150),
    );
    state.avatarFgScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: state.avatarFgCtrl, curve: Curves.easeOutBack),
    );
    if (animate) {
      Future.delayed(const Duration(milliseconds: 160), () {
        if (!state.disposed) state.avatarFgCtrl.forward();
      });
    } else {
      state.avatarFgCtrl.value = 1.0;
    }

    state.msgHCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 180),
    );
    state.msgHScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: state.msgHCtrl, curve: Curves.easeOutBack),
    );
    if (animate) {
      state.msgHCtrl.forward();
    } else {
      state.msgHCtrl.value = 1.0;
    }

    state.msgVCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 180),
    );
    state.msgVScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: state.msgVCtrl, curve: Curves.easeOutBack),
    );
    if (animate) {
      state.msgVCtrl.forward();
    } else {
      state.msgVCtrl.value = 1.0;
    }

    state.msgAlphaCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 130),
    );
    state.msgAlpha = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(state.msgAlphaCtrl);
    if (animate) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!state.disposed) state.msgAlphaCtrl.forward();
      });
    } else {
      state.msgAlphaCtrl.value = 1.0;
    }

    state.lineCtrl = AnimationController(
      vsync: vsync,
      duration: const Duration(milliseconds: 180),
    );
    state.lineProgress = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(state.lineCtrl);

    // ── Finalize PREVIOUS entry ──────────────────────────────────────────
    // Tiny random jitter (±8 dp) for visual variety without forced zigzag.
    // Then FREEZE bottom coords before starting the line animation so later
    // shifts on `state` can't move the already-drawn line.
    if (_entries.isNotEmpty) {
      final prev = _entries.last;
      final skipsOutgoingMedia =
          (prev.message.sender == Sender.ren && prev.message.isAnimatedMedia) ||
          (state.message.sender == Sender.ren && state.message.isAnimatedMedia);
      if (skipsOutgoingMedia) {
        _entries.add(state);
        if (notify) notifyListeners();
        return;
      }
      // Skip jitter for image messages — their line is anchored at a fixed center
      if (prev.message.sender != Sender.ren &&
          !prev.message.isImage &&
          !prev.message.isAnimatedMedia) {
        final shift = (_rng.nextDouble() * 16) - 8; // –8 … +8 dp
        prev.lineLeft = prev.lineLeft + Offset(shift, 0);
        prev.lineRight = prev.lineRight + Offset(shift, 0);
      }
      prev.frozenBottomLeft = state.lineLeft;
      prev.frozenBottomRight = state.lineRight;
      prev.frozenNextIsRen = state.message.sender == Sender.ren;
      prev.frozenNextIsSticker = state.message.isAnimatedMedia;

      // Random line shape: Z-jog only on cross-sender connections.
      // The jog goes AGAINST the direction of travel to form a proper Z-shape.
      if (!prev.message.isAnimatedMedia && !state.message.isAnimatedMedia) {
        final crossSender = prev.message.sender != state.message.sender;
        if (crossSender && _rng.nextDouble() < 0.55) {
          prev.lineStyle = LineStyle.zJog;
          final mag = 12.0 + _rng.nextDouble() * 8.0; // 12..20 dp
          // Going left→Ren means line travels right → jog left (negative).
          // Going Ren→left means line travels left → jog right (positive).
          final goingRight = state.message.sender == Sender.ren;
          prev.jogOffsetX = goingRight ? -mag : mag;
          prev.jogFraction = 0.30 + _rng.nextDouble() * 0.35; // 0.30..0.65
        } else {
          prev.lineStyle = LineStyle.straight;
        }
      }

      if (animate) {
        prev.lineCtrl.forward();
      } else {
        prev.lineCtrl.value = 1.0;
      }
    }

    _entries.add(state);
    if (notify) notifyListeners();
  }

  void _rebuildVisibleEntries() {
    for (final entry in _entries) {
      entry.dispose();
    }
    _entries.clear();
    _messageIndex = 0;
    while (_messageIndex < _messages.length) {
      _showMessage(_messages[_messageIndex++], animate: false, notify: false);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }
}

// ── Transcript widget ──────────────────────────────────────────────────────

class Transcript extends StatefulWidget {
  final TranscriptState state;
  final Future<bool> Function()? onLoadOlder;
  final double bottomPadding;

  const Transcript({
    super.key,
    required this.state,
    this.onLoadOlder,
    this.bottomPadding = 180,
  });

  @override
  State<Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<Transcript> with WidgetsBindingObserver {
  final _scrollCtrl = ScrollController();
  bool _loadingOlder = false;
  Timer? _keyboardScrollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.state.addListener(_onStateChanged);
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToBottom());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keyboardScrollTimer?.cancel();
    widget.state.removeListener(_onStateChanged);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    if (!_scrollCtrl.hasClients) return;
    final position = _scrollCtrl.position;
    final wasAtBottom = position.maxScrollExtent - position.pixels < 220;
    if (!wasAtBottom) return;

    _keyboardScrollTimer?.cancel();
    _keyboardScrollTimer = Timer(const Duration(milliseconds: 55), () {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _animateToBottom());
    });
  }

  void _onStateChanged() {
    if (!mounted) return;
    final preservePosition = widget.state.takeSuppressNextAutoScroll();
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (preservePosition) return;
      _animateToBottom();
    });
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients ||
        _loadingOlder ||
        widget.onLoadOlder == null) {
      return;
    }
    if (_scrollCtrl.position.pixels <= 90) {
      unawaited(_loadOlder());
    }
  }

  Future<void> _loadOlder() async {
    final onLoadOlder = widget.onLoadOlder;
    if (onLoadOlder == null || !_scrollCtrl.hasClients) return;

    _loadingOlder = true;
    final beforeMaxExtent = _scrollCtrl.position.maxScrollExtent;
    final beforePixels = _scrollCtrl.position.pixels;
    bool loaded;
    try {
      loaded = await onLoadOlder();
    } catch (_) {
      _loadingOlder = false;
      return;
    }
    if (!mounted) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (loaded) {
        final delta = _scrollCtrl.position.maxScrollExtent - beforeMaxExtent;
        _scrollCtrl.jumpTo(
          (beforePixels + delta).clamp(
            _scrollCtrl.position.minScrollExtent,
            _scrollCtrl.position.maxScrollExtent,
          ),
        );
      }
      _loadingOlder = false;
    });
  }

  void _jumpToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
  }

  void _animateToBottom() {
    if (!_scrollCtrl.hasClients) return;
    _scrollCtrl.animateTo(
      _scrollCtrl.position.maxScrollExtent,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.state._visibleEntries;
    return ListView.separated(
      controller: _scrollCtrl,
      padding: EdgeInsets.only(
        // Clear the fixed-height ChatHeader, including two-line chat titles.
        top: MediaQuery.of(context).padding.top + 142,
        // Extra 80 dp so the last item clears the floating InputBar (~70 dp)
        bottom: widget.bottomPadding + MediaQuery.of(context).padding.bottom,
      ),
      itemCount: entries.length,
      separatorBuilder: (context, index) =>
          const SizedBox(height: kEntrySpacing),
      itemBuilder: (context, index) {
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
          builder: (context, child) => _buildItem(entry),
        );
      },
    );
  }

  Widget _buildItem(_EntryState entry) {
    Widget item;
    // Content type takes priority over sender — Ren can send images/stickers too.
    if (entry.message.isImage) {
      item = ImageBubble(
        message: entry.message,
        hScale: entry.msgHScale.value,
        vScale: entry.msgVScale.value,
        alpha: entry.msgAlpha.value,
      );
    } else if (entry.message.isFile) {
      item = FileBubble(
        message: entry.message,
        hScale: entry.msgHScale.value,
        vScale: entry.msgVScale.value,
        alpha: entry.msgAlpha.value,
      );
    } else if (entry.message.isAnimatedMedia) {
      item = StickerBubble(
        message: entry.message,
        avatarBackgroundScale: entry.avatarBgScale.value,
        avatarForegroundScale: entry.avatarFgScale.value,
        scale: entry.msgHScale.value,
        alpha: entry.msgAlpha.value,
      );
    } else if (entry.message.sender == Sender.ren) {
      item = ReplyBubble(
        text: entry.message.text,
        messageHorizontalScale: entry.msgHScale.value,
        messageVerticalScale: entry.msgVScale.value,
        messageTextAlpha: entry.msgAlpha.value,
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
        currentIsSticker: entry.message.isAnimatedMedia,
        currentLineLeft: entry.lineLeft,
        currentLineRight: entry.lineRight,
        nextIsRen: entry.frozenNextIsRen,
        nextIsSticker: entry.frozenNextIsSticker,
        nextLineLeft: entry.frozenBottomLeft!,
        nextLineRight: entry.frozenBottomRight!,
        lineProgress: entry.lineProgress.value,
        lineStyle: entry.lineStyle,
        jogOffsetX: entry.jogOffsetX,
        jogFraction: entry.jogFraction,
      ),
      child: item,
    );
  }
}
