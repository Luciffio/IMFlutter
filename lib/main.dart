import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models/auth_session.dart';
import 'models/chat_summary.dart';
import 'models/message.dart';
import 'services/chat_repository.dart';
import 'services/mock_chat_repository.dart';
import 'services/telegram_repository.dart';
import 'theme/persona_colors.dart';
import 'widgets/auth_screen.dart';
import 'widgets/background_particles.dart';
import 'widgets/chat_header.dart';
import 'widgets/chat_list_screen.dart';
import 'widgets/input_bar.dart';
import 'widgets/persona_progress.dart';
import 'widgets/transcript.dart';

const _activeAccountSlotKey = 'telegram.activeAccountSlot';
const _accountSlotsKey = 'telegram.accountSlots';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  final int initialAccountSlot;
  final List<int> initialAccountSlots;

  const MainApp({
    super.key,
    this.initialAccountSlot = 0,
    this.initialAccountSlots = const [0],
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kPersonaRed,
        fontFamilyFallback: const ['Bitter'],
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: _NoTransitionsBuilder(),
            TargetPlatform.iOS: _NoTransitionsBuilder(),
            TargetPlatform.windows: _NoTransitionsBuilder(),
            TargetPlatform.macOS: _NoTransitionsBuilder(),
            TargetPlatform.linux: _NoTransitionsBuilder(),
          },
        ),
      ),
      home: _RootShell(
        initialAccountSlot: initialAccountSlot,
        initialAccountSlots: initialAccountSlots,
      ),
    );
  }
}

class _NoTransitionsBuilder extends PageTransitionsBuilder {
  const _NoTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

/// Owns the [ChatRepository] connection and routes between the chat list
/// and an individual conversation.
class _RootShell extends StatefulWidget {
  final int initialAccountSlot;
  final List<int> initialAccountSlots;

  const _RootShell({
    required this.initialAccountSlot,
    required this.initialAccountSlots,
  });

  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell> {
  static const _particleModeKey = 'settings.particleMode';
  static const _transitionsKey = 'settings.transitionAnimationsEnabled';
  static const _telegramApiId = int.fromEnvironment('TG_API_ID');
  static const _telegramApiHash = String.fromEnvironment('TG_API_HASH');
  static const _hasTelegramCredentials =
      _telegramApiId != 0 && _telegramApiHash != '';
  static const _useTelegramBackend =
      bool.fromEnvironment('USE_TELEGRAM') || _hasTelegramCredentials;
  static ChatRepository? _retainedTelegramRepository;
  static int? _retainedTelegramSlot;

  late ChatRepository _chatRepo;
  StreamSubscription<AuthSessionState>? _authSub;
  late int _activeAccountSlot;
  late List<int> _accountSlots;
  int _repositoryGeneration = 0;
  bool _showAuth = false;
  PersonaParticleMode _particleMode = PersonaParticleMode.spring;
  bool _transitionAnimationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _activeAccountSlot = widget.initialAccountSlot;
    _accountSlots = [...widget.initialAccountSlots];
    _chatRepo = _createRepository();
    _bindRepository();
    _loadSettings();
  }

  void _bindRepository() {
    if (_useTelegramBackend) {
      _authSub = _chatRepo.authState.listen(_syncTelegramAuthState);
    }
    unawaited(_connectRepository());
  }

  Future<void> _connectRepository() async {
    await _chatRepo.connect();
    if (!_useTelegramBackend || !mounted) return;
    _syncTelegramAuthState(await _chatRepo.getAuthState());
  }

  @override
  void dispose() {
    _authSub?.cancel();
    if (!_useTelegramBackend) unawaited(_chatRepo.disconnect());
    super.dispose();
  }

  void _syncTelegramAuthState(AuthSessionState state) {
    if (!mounted) return;
    final shouldShowAuth = !state.isReady;
    if (_showAuth == shouldShowAuth) return;
    setState(() => _showAuth = shouldShowAuth);
  }

  Future<void> _switchAccount(int slot) async {
    if (!_useTelegramBackend || slot == _activeAccountSlot) return;
    final previousRepository = _chatRepo;
    await _authSub?.cancel();
    _authSub = null;
    await previousRepository.disconnect();
    if (identical(_retainedTelegramRepository, previousRepository)) {
      _retainedTelegramRepository = null;
      _retainedTelegramSlot = null;
    }

    _activeAccountSlot = slot;
    if (!_accountSlots.contains(slot)) {
      _accountSlots = [..._accountSlots, slot]..sort();
    }
    _chatRepo = _createRepository();
    _repositoryGeneration++;
    _showAuth = false;
    _bindRepository();
    await _persistAccountState();
    if (mounted) setState(() {});
  }

  Future<void> _addAccount() async {
    final nextSlot = _accountSlots.isEmpty
        ? 0
        : _accountSlots.reduce((a, b) => a > b ? a : b) + 1;
    await _switchAccount(nextSlot);
  }

  Future<void> _signOutCurrentAccount() async {
    await _chatRepo.signOut();
    if (!mounted) return;
    setState(() => _showAuth = true);
  }

  Future<void> _persistAccountState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeAccountSlotKey, _activeAccountSlot);
    await prefs.setStringList(
      _accountSlotsKey,
      _accountSlots.map((slot) => slot.toString()).toList(),
    );
  }

  void _openChat(BuildContext context, ChatSummary chat) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: _transitionAnimationsEnabled
            ? const Duration(milliseconds: 360)
            : Duration.zero,
        reverseTransitionDuration: _transitionAnimationsEnabled
            ? const Duration(milliseconds: 280)
            : Duration.zero,
        pageBuilder: (_, _, _) => ChatScreen(
          chat: chat,
          repository: _chatRepo,
          particleSeason: resolvePersonaSeason(_particleMode),
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          if (!_transitionAnimationsEnabled) return child;

          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          final slide = Tween<Offset>(
            begin: const Offset(1.08, 0.04),
            end: Offset.zero,
          ).animate(curved);
          final scale = Tween<double>(begin: 0.94, end: 1).animate(curved);
          final turn = Tween<double>(begin: 0.012, end: 0).animate(curved);

          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: slide,
              child: ScaleTransition(
                scale: scale,
                child: AnimatedBuilder(
                  animation: turn,
                  child: child,
                  builder: (context, child) =>
                      Transform.rotate(angle: turn.value, child: child),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    final storedActiveSlot = prefs.getInt(_activeAccountSlotKey) ?? 0;
    final storedSlots = prefs
        .getStringList(_accountSlotsKey)
        ?.map(int.tryParse)
        .whereType<int>();

    setState(() {
      _particleMode = _particleModeFromName(prefs.getString(_particleModeKey));
      _transitionAnimationsEnabled =
          prefs.getBool(_transitionsKey) ?? _transitionAnimationsEnabled;
      _accountSlots = <int>{0, storedActiveSlot, ...?storedSlots}.toList()
        ..sort();
    });
    if (_useTelegramBackend && storedActiveSlot != _activeAccountSlot) {
      await _switchAccount(storedActiveSlot);
    }
  }

  Future<void> _setParticleMode(PersonaParticleMode mode) async {
    setState(() => _particleMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_particleModeKey, mode.name);
  }

  Future<void> _setTransitionAnimationsEnabled(bool enabled) async {
    setState(() => _transitionAnimationsEnabled = enabled);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_transitionsKey, enabled);
  }

  PersonaParticleMode _particleModeFromName(String? value) {
    return PersonaParticleMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => PersonaParticleMode.spring,
    );
  }

  ChatRepository _createRepository() {
    if (!_useTelegramBackend) return MockChatRepository();

    final retained = _retainedTelegramRepository;
    if (retained != null && _retainedTelegramSlot == _activeAccountSlot) {
      return retained;
    }

    final repository = TelegramRepository(
      apiId: _telegramApiId,
      apiHash: _telegramApiHash,
      databaseSuffix: _activeAccountSlot == 0
          ? ''
          : '.account_$_activeAccountSlot',
    );
    _retainedTelegramRepository = repository;
    _retainedTelegramSlot = _activeAccountSlot;
    return repository;
  }

  @override
  Widget build(BuildContext context) {
    final particleSeason = resolvePersonaSeason(_particleMode);

    return AnimatedSwitcher(
      duration: _transitionAnimationsEnabled
          ? const Duration(milliseconds: 420)
          : Duration.zero,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        if (!_transitionAnimationsEnabled) return child;

        final slide = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: _showAuth
          ? AuthScreen(
              key: const ValueKey('auth'),
              repository: _chatRepo,
              onAuthenticated: () => setState(() => _showAuth = false),
              onCancel: () => setState(() {
                _showAuth = _useTelegramBackend;
              }),
            )
          : ChatListScreen(
              key: ValueKey('chat_list_$_repositoryGeneration'),
              repository: _chatRepo,
              accountSlots: _accountSlots,
              activeAccountSlot: _activeAccountSlot,
              particleMode: _particleMode,
              particleSeason: particleSeason,
              transitionAnimationsEnabled: _transitionAnimationsEnabled,
              onParticleModeChanged: _setParticleMode,
              onTransitionAnimationsChanged: _setTransitionAnimationsEnabled,
              onOpenChat: (chat) => _openChat(context, chat),
              onOpenAuth: () => setState(() => _showAuth = true),
              onSwitchAccount: _switchAccount,
              onAddAccount: _addAccount,
              onSignOut: _signOutCurrentAccount,
            ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final ChatSummary chat;
  final ChatRepository repository;
  final PersonaSeason particleSeason;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.repository,
    required this.particleSeason,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  static const _backSwipeStartWidth = 132.0;
  static const _backSwipeTriggerDx = 46.0;
  static const _backSwipeVerticalSlack = 74.0;

  TranscriptState? _transcriptState;
  StreamSubscription<Message>? _incomingSub;
  StreamSubscription<Message>? _messageUpdateSub;
  StreamSubscription<ChatTypingUpdate>? _typingSub;
  bool _isSomeoneTyping = false;
  bool _usesLiveHistory = false;
  bool _loadingOlderMessages = false;
  bool _hasMoreOlderMessages = true;
  List<ComposerMediaItem> _gifItems = const [];
  List<ComposerMediaItem> _stickerItems = const [];
  final _inputBarController = InputBarController();
  bool _isComposerOpen = false;
  int? _backSwipePointer;
  Offset? _backSwipeStart;

  @override
  void initState() {
    super.initState();
    _loadTranscript();
    unawaited(_loadComposerMedia());

    _incomingSub = widget.repository.incomingMessages.listen((msg) {
      if (msg.chatId == widget.chat.id) {
        _transcriptState?.addMessage(msg);
      }
    });
    _messageUpdateSub = widget.repository.messageUpdates.listen((msg) {
      if (msg.chatId == widget.chat.id) {
        _transcriptState?.replaceMessage(msg);
      }
    });
    _typingSub = widget.repository.typingUpdates.listen((update) {
      if (update.chatId != widget.chat.id) return;
      _isSomeoneTyping = update.isTyping;
      _transcriptState?.setSomeoneTyping(update.isTyping);
    });
  }

  Future<void> _loadComposerMedia() async {
    final results = await Future.wait([
      widget.repository.getSavedGifs().catchError(
        (_) => const <ComposerMediaItem>[],
      ),
      widget.repository.getSavedStickers().catchError(
        (_) => const <ComposerMediaItem>[],
      ),
    ]);
    if (!mounted) return;
    setState(() {
      _gifItems = results[0];
      _stickerItems = results[1];
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _messageUpdateSub?.cancel();
    _typingSub?.cancel();
    _inputBarController.dispose();
    _transcriptState?.dispose();
    super.dispose();
  }

  Future<void> _loadTranscript() async {
    final messages = await widget.repository.getMessages(widget.chat.id);
    if (!mounted) return;

    final usesLiveHistory = messages.any((message) => message.id != null);
    final state = TranscriptState(vsync: this, messages: messages);
    state.setSomeoneTyping(_isSomeoneTyping);
    if (usesLiveHistory) {
      state.showAll();
    } else {
      state.advance();
    }
    setState(() {
      _usesLiveHistory = usesLiveHistory;
      _transcriptState = state;
    });
    unawaited(widget.repository.markChatOpened(widget.chat.id));
  }

  void _onSend(String text) {
    final state = _transcriptState;
    if (state == null) return;

    state.addMessage(
      Message(
        chatId: widget.chat.id,
        sender: Sender.ren,
        text: text,
        createdAt: DateTime.now(),
        status: MessageDeliveryStatus.sent,
      ),
    );
    unawaited(widget.repository.sendMessage(widget.chat.id, text));
  }

  Future<void> _onSendPhotos(List<String> paths, String caption) async {
    final messages = await widget.repository.sendPhotos(
      widget.chat.id,
      paths,
      caption: caption,
    );
    for (final message in messages) {
      _transcriptState?.addMessage(message);
    }
  }

  Future<void> _onSendFile(
    String path,
    String name,
    int size,
    String caption,
  ) async {
    final message = await widget.repository.sendFile(
      widget.chat.id,
      path,
      name: name,
      size: size,
      caption: caption,
    );
    _transcriptState?.addMessage(message);
  }

  Future<void> _onSendSticker(String path) async {
    final message = await widget.repository.sendSticker(widget.chat.id, path);
    _transcriptState?.addMessage(message);
  }

  Future<void> _onSendGif(String path, String caption) async {
    final message = await widget.repository.sendGif(
      widget.chat.id,
      path,
      caption: caption,
    );
    _transcriptState?.addMessage(message);
  }

  Future<bool> _loadOlderMessages() async {
    final state = _transcriptState;
    final oldestId = state?.oldestMessageId;
    if (state == null ||
        oldestId == null ||
        _loadingOlderMessages ||
        !_hasMoreOlderMessages) {
      return false;
    }

    _loadingOlderMessages = true;
    try {
      final older = await widget.repository.getMessagesBefore(
        widget.chat.id,
        oldestId,
      );
      if (!mounted) return false;
      if (older.isEmpty) {
        _hasMoreOlderMessages = false;
        return false;
      }
      state.prependMessages(older);
      return true;
    } finally {
      _loadingOlderMessages = false;
    }
  }

  void _onBackPointerDown(PointerDownEvent event) {
    // The outer edge belongs to Android's system back gesture, so accept the
    // swipe from a wider in-app strip as well.
    if (event.position.dx > _backSwipeStartWidth || _backSwipePointer != null) {
      return;
    }
    _backSwipePointer = event.pointer;
    _backSwipeStart = event.position;
  }

  void _onBackPointerMove(PointerMoveEvent event) {
    if (event.pointer != _backSwipePointer || _backSwipeStart == null) return;
    final delta = event.position - _backSwipeStart!;
    if (_shouldCancelBackSwipe(delta)) {
      _resetBackPointer();
      return;
    }
    if (_shouldTriggerBackSwipe(delta)) {
      _resetBackPointer();
      _exitChatFromSwipe();
    }
  }

  void _onBackPointerUp(PointerUpEvent event) {
    if (event.pointer != _backSwipePointer || _backSwipeStart == null) return;
    final delta = event.position - _backSwipeStart!;
    _resetBackPointer();
    if (_shouldTriggerBackSwipe(delta)) {
      _exitChatFromSwipe();
    }
  }

  bool _shouldCancelBackSwipe(Offset delta) {
    final vertical = delta.dy.abs();
    if (delta.dx < -8) return true;
    return vertical > _backSwipeVerticalSlack && vertical > delta.dx * 1.45;
  }

  bool _shouldTriggerBackSwipe(Offset delta) {
    final vertical = delta.dy.abs();
    return delta.dx >= _backSwipeTriggerDx &&
        vertical <= _backSwipeVerticalSlack &&
        delta.dx >= vertical * 0.55;
  }

  void _resetBackPointer() {
    _backSwipePointer = null;
    _backSwipeStart = null;
  }

  void _exitChatFromSwipe() {
    _closeComposer();
    Navigator.of(context).pop();
  }

  void _closeComposer() {
    _inputBarController.closeComposer();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  void _setComposerOpen(bool isOpen) {
    if (!mounted || _isComposerOpen == isOpen) return;
    setState(() => _isComposerOpen = isOpen);
  }

  @override
  Widget build(BuildContext context) {
    final transcriptState = _transcriptState;
    final canSendMessages = widget.chat.type != ChatType.channel;

    // Best-effort mapping from the chat's participants back to the hardcoded
    // [Sender] enum so the existing ChatHeader can render its avatar strip.
    // Real Telegram data won't line up with these faces; this just keeps the
    // mock demo coherent.
    final participants = widget.chat.participants
        .map((p) => _senderForName(p.name))
        .whereType<Sender>()
        .toList();

    return PopScope(
      canPop: !_isComposerOpen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isComposerOpen) _closeComposer();
      },
      child: Scaffold(
        backgroundColor: kPersonaRed,
        resizeToAvoidBottomInset: true,
        body: Listener(
          key: const ValueKey('chat_edge_back'),
          behavior: HitTestBehavior.translucent,
          onPointerDown: _onBackPointerDown,
          onPointerMove: _onBackPointerMove,
          onPointerUp: _onBackPointerUp,
          onPointerCancel: (_) => _resetBackPointer(),
          child: Stack(
            children: [
              Positioned.fill(
                child: BackgroundParticles(season: widget.particleSeason),
              ),
              if (transcriptState == null)
                const Center(child: PersonaLoadingMark(label: 'CHAT'))
              else
                GestureDetector(
                  onTap: _usesLiveHistory
                      ? null
                      : transcriptState.advanceAfterTyping,
                  child: Transcript(
                    state: transcriptState,
                    onLoadOlder: _usesLiveHistory ? _loadOlderMessages : null,
                    bottomPadding: canSendMessages ? 180 : 78,
                  ),
                ),

              Align(
                alignment: Alignment.topCenter,
                child: ChatHeader(
                  chatName: widget.chat.title,
                  participants: participants,
                  onBack: () => Navigator.of(context).pop(),
                ),
              ),

              if (canSendMessages)
                Align(
                  alignment: Alignment.bottomCenter,
                  child: transcriptState == null
                      ? const SizedBox.shrink()
                      : AnimatedBuilder(
                          animation: transcriptState,
                          builder: (context, _) => InputBar(
                            controller: _inputBarController,
                            onComposerOpenChanged: _setComposerOpen,
                            showTypingIndicator:
                                transcriptState.isSomeoneTyping,
                            onSend: _onSend,
                            onSendPhotos: _onSendPhotos,
                            onSendFile: _onSendFile,
                            onSendSticker: _onSendSticker,
                            onSendGif: _onSendGif,
                            gifItems: _gifItems,
                            stickerItems: _stickerItems,
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Sender? _senderForName(String name) {
    switch (name.toLowerCase()) {
      case 'ann':
        return Sender.ann;
      case 'ryuji':
        return Sender.ryuji;
      case 'yusuke':
        return Sender.yusuke;
      default:
        return null;
    }
  }
}
