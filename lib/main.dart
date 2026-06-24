import 'dart:async';
import 'package:flutter/material.dart';
import 'models/chat_summary.dart';
import 'models/message.dart';
import 'services/chat_repository.dart';
import 'services/mock_chat_repository.dart';
// import 'services/telegram_repository.dart'; // ← swap here when backend ready
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
  late final ChatRepository _chatRepo;
  bool _showAuth = false;

  @override
  void initState() {
    super.initState();
    _chatRepo = MockChatRepository();
    _chatRepo.connect();
  }

  @override
  void dispose() {
    _chatRepo.disconnect();
    super.dispose();
  }

  void _openChat(BuildContext context, ChatSummary chat) {
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        pageBuilder: (_, _, _) => ChatScreen(chat: chat, repository: _chatRepo),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
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

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 420),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
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
              onAuthenticated: () => setState(() => _showAuth = false),
              onCancel: () => setState(() => _showAuth = false),
            )
          : ChatListScreen(
              key: const ValueKey('chat_list'),
              repository: _chatRepo,
              onOpenChat: (chat) => _openChat(context, chat),
              onOpenAuth: () => setState(() => _showAuth = true),
            ),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final ChatSummary chat;
  final ChatRepository repository;

  const ChatScreen({super.key, required this.chat, required this.repository});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late final TranscriptState _transcriptState;
  StreamSubscription<Message>? _incomingSub;

  @override
  void initState() {
    super.initState();

    _transcriptState = TranscriptState(vsync: this, messages: kMessages);
    _transcriptState.advance();

    _incomingSub = widget.repository.incomingMessages.listen((msg) {
      _transcriptState.addMessage(msg);
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _transcriptState.dispose();
    super.dispose();
  }

  void _onSend(String text) {
    _transcriptState.addMessage(Message(sender: Sender.ren, text: text));
    widget.repository.sendMessage(text);
  }

  void _onSendImage(String path) {
    _transcriptState.addMessage(Message(sender: Sender.ren, imagePath: path));
  }

  void _onSendFile(String path, String name, int size) {
    _transcriptState.addMessage(
      Message(
        sender: Sender.ren,
        filePath: path,
        fileName: name,
        fileSize: size,
      ),
    );
  }

  void _onSendSticker(String path) {
    _transcriptState.addMessage(Message(sender: Sender.ren, stickerPath: path));
  }

  void _onSendGif(String path) {
    _transcriptState.addMessage(Message(sender: Sender.ren, gifPath: path));
  }

  @override
  Widget build(BuildContext context) {
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
          const Positioned.fill(child: BackgroundParticles()),
          GestureDetector(
            onTap: _transcriptState.advanceAfterTyping,
            child: Transcript(state: _transcriptState),
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
            child: AnimatedBuilder(
              animation: _transcriptState,
              builder: (context, _) => InputBar(
                showTypingIndicator: _transcriptState.isSomeoneTyping,
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
