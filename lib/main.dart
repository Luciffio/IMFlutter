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
import 'widgets/transcript.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: kPersonaRed,
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
      home: const _RootShell(),
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
  const _RootShell();

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

  late final ChatRepository _chatRepo;
  StreamSubscription<AuthSessionState>? _authSub;
  bool _showAuth = _useTelegramBackend;
  PersonaParticleMode _particleMode = PersonaParticleMode.spring;
  bool _transitionAnimationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _chatRepo = _createRepository();
    _chatRepo.connect();
    if (_useTelegramBackend) {
      _authSub = _chatRepo.authState.listen(_syncTelegramAuthState);
    }
    _loadSettings();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _chatRepo.disconnect();
    super.dispose();
  }

  void _syncTelegramAuthState(AuthSessionState state) {
    if (!mounted) return;
    final shouldShowAuth = !state.isReady;
    if (_showAuth == shouldShowAuth) return;
    setState(() => _showAuth = shouldShowAuth);
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

    setState(() {
      _particleMode = _particleModeFromName(prefs.getString(_particleModeKey));
      _transitionAnimationsEnabled =
          prefs.getBool(_transitionsKey) ?? _transitionAnimationsEnabled;
    });
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

    return TelegramRepository(apiId: _telegramApiId, apiHash: _telegramApiHash);
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
              key: const ValueKey('chat_list'),
              repository: _chatRepo,
              particleMode: _particleMode,
              particleSeason: particleSeason,
              transitionAnimationsEnabled: _transitionAnimationsEnabled,
              onParticleModeChanged: _setParticleMode,
              onTransitionAnimationsChanged: _setTransitionAnimationsEnabled,
              onOpenChat: (chat) => _openChat(context, chat),
              onOpenAuth: () => setState(() => _showAuth = true),
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
  TranscriptState? _transcriptState;
  StreamSubscription<Message>? _incomingSub;

  @override
  void initState() {
    super.initState();
    _loadTranscript();

    _incomingSub = widget.repository.incomingMessages.listen((msg) {
      if (msg.chatId == widget.chat.id) {
        _transcriptState?.addMessage(msg);
      }
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _transcriptState?.dispose();
    super.dispose();
  }

  Future<void> _loadTranscript() async {
    final messages = await widget.repository.getMessages(widget.chat.id);
    if (!mounted) return;

    final state = TranscriptState(vsync: this, messages: messages);
    if (messages.any((message) => message.id != null)) {
      state.showAll();
    } else {
      state.advance();
    }
    setState(() => _transcriptState = state);
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

  void _onSendImage(String path) {
    _transcriptState?.addMessage(
      Message(sender: Sender.ren, chatId: widget.chat.id, imagePath: path),
    );
  }

  void _onSendFile(String path, String name, int size) {
    _transcriptState?.addMessage(
      Message(
        chatId: widget.chat.id,
        sender: Sender.ren,
        filePath: path,
        fileName: name,
        fileSize: size,
      ),
    );
  }

  void _onSendSticker(String path) {
    _transcriptState?.addMessage(
      Message(sender: Sender.ren, chatId: widget.chat.id, stickerPath: path),
    );
  }

  void _onSendGif(String path) {
    _transcriptState?.addMessage(
      Message(sender: Sender.ren, chatId: widget.chat.id, gifPath: path),
    );
  }

  @override
  Widget build(BuildContext context) {
    final transcriptState = _transcriptState;

    // Best-effort mapping from the chat's participants back to the hardcoded
    // [Sender] enum so the existing ChatHeader can render its avatar strip.
    // Real Telegram data won't line up with these faces; this just keeps the
    // mock demo coherent.
    final participants = widget.chat.participants
        .map((p) => _senderForName(p.name))
        .whereType<Sender>()
        .toList();

    return Scaffold(
      backgroundColor: kPersonaRed,
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          Positioned.fill(
            child: BackgroundParticles(season: widget.particleSeason),
          ),
          if (transcriptState == null)
            const Center(child: CircularProgressIndicator(color: Colors.white))
          else
            GestureDetector(
              onTap: transcriptState.advanceAfterTyping,
              child: Transcript(state: transcriptState),
            ),

          Align(
            alignment: Alignment.topCenter,
            child: ChatHeader(
              chatName: widget.chat.title,
              participants: participants,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: transcriptState == null
                ? const SizedBox.shrink()
                : AnimatedBuilder(
                    animation: transcriptState,
                    builder: (context, _) => InputBar(
                      showTypingIndicator: transcriptState.isSomeoneTyping,
                      onSend: _onSend,
                      onSendImage: _onSendImage,
                      onSendFile: _onSendFile,
                      onSendSticker: _onSendSticker,
                      onSendGif: _onSendGif,
                    ),
                  ),
          ),
        ],
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
