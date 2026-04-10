import 'package:flutter/material.dart';
import 'models/message.dart';
import 'theme/persona_colors.dart';
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

  @override
  void initState() {
    super.initState();
    _transcriptState = TranscriptState(vsync: this, messages: kMessages);
    _transcriptState.advance(); // show first message immediately
  }

  @override
  void dispose() {
    _transcriptState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPersonaRed,
      body: GestureDetector(
        onTap: _transcriptState.advance, // tap anywhere to show next message
        child: Transcript(state: _transcriptState),
      ),
    );
  }
}
