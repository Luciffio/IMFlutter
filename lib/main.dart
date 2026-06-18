import 'dart:async';
import 'package:flutter/material.dart';
import 'models/chat_summary.dart';
import 'models/message.dart';
import 'services/chat_repository.dart';
import 'services/mock_chat_repository.dart';
// import 'services/telegram_repository.dart'; // ← swap here when backend ready
import 'theme/persona_colors.dart';
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
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, _, _) =>
            ChatScreen(chat: chat, repository: _chatRepo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChatListScreen(
      repository: _chatRepo,
      onOpenChat: (chat) => _openChat(context, chat),
    );
  }
}

class ChatScreen extends StatefulWidget {
  final ChatSummary chat;
  final ChatRepository repository;

  const ChatScreen({
    super.key,
    required this.chat,
    required this.repository,
  });

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
          GestureDetector(
            onTap: _transcriptState.advance,
            child: Transcript(state: _transcriptState),
          ),

          Align(
            alignment: Alignment.topCenter,
            child: ChatHeader(
              chatName: widget.chat.title,
              participants: participants,
            ),
          ),

          // Back button — returns to the chat list.
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: _BackButton(onTap: () => Navigator.of(context).pop()),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: InputBar(onSend: _onSend, onSendImage: _onSendImage),
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

class _BackButton extends StatelessWidget {
  final VoidCallback onTap;
  const _BackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
      ),
    );
  }
}
