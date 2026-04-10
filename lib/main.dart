import 'package:flutter/material.dart';
import 'models/message.dart';
import 'theme/persona_colors.dart';
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
      // resizeToAvoidBottomInset keeps the bar above the software keyboard
      resizeToAvoidBottomInset: true,
      body: Stack(
        children: [
          // Chat transcript — tap anywhere (except the bar) to advance
          GestureDetector(
            onTap: _transcriptState.advance,
            child: Transcript(state: _transcriptState),
          ),

          // Input bar pinned to the bottom
          Align(
            alignment: Alignment.bottomCenter,
            child: InputBar(
              onSend: (text) {
                // TODO: send real message once backend is wired up
              },
            ),
          ),
        ],
      ),
    );
  }
}
