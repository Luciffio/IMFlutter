import 'dart:async';
import 'package:flutter/material.dart';
import 'models/message.dart';
import 'services/chat_repository.dart';
import 'services/mock_chat_repository.dart';
// import 'services/tele  gram_repository.dart'; // ← swap here when backend ready
import 'theme/persona_colors.dart';
import 'widgets/chat_header.dart';
import 'widgets/input_bar.dart';
import 'widgets/transcript.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ChatScreen(),
    );
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  late final TranscriptState _transcriptState;
  late final ChatRepository _chatRepo;
  StreamSubscription<Message>? _incomingSub;

  @override
  void initState() {
    super.initState();

    _transcriptState = TranscriptState(vsync: this, messages: kMessages);
    _transcriptState.advance();

    _chatRepo = MockChatRepository();
    _chatRepo.connect();

    _incomingSub = _chatRepo.incomingMessages.listen((msg) {
      _transcriptState.addMessage(msg);
    });
  }

  @override
  void dispose() {
    _incomingSub?.cancel();
    _chatRepo.disconnect();
    _transcriptState.dispose();
    super.dispose();
  }

  void _onSend(String text) {
    _transcriptState.addMessage(Message(sender: Sender.ren, text: text));
    _chatRepo.sendMessage(text);
  }

  void _onSendImage(String path) {
    _transcriptState.addMessage(Message(sender: Sender.ren, imagePath: path));
  }

  @override
  Widget build(BuildContext context) {
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
              chatName: 'Phantom Thieves',
              participants: Sender.values.where((s) => s != Sender.ren).toList(),
            ),
          ),

          Align(
            alignment: Alignment.bottomCenter,
            child: InputBar(onSend: _onSend, onSendImage: _onSendImage),
          ),
        ],
      ),
    );
  }
}
