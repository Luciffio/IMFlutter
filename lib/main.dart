import 'dart:async';
import 'package:flutter/material.dart';
import 'models/message.dart';
import 'services/chat_repository.dart';
import 'services/mock_chat_repository.dart';
// import 'services/telegram_repository.dart'; // ← swap here when backend ready
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

  // 0 = Bangers, 1 = Boogaloo, 2 = PermanentMarker
  int _fontIndex = 0;

  static const _fontFamilies = ['Bangers', 'Boogaloo', 'PermanentMarker', 'Fruktur', 'RubikVinyl'];
  static const _fontLabels   = ['1 · Bangers', '2 · Boogaloo', '3 · Permanent Marker', '4 · Fruktur', '5 · Rubik Vinyl'];

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

          // Header
          Align(
            alignment: Alignment.topCenter,
            child: ChatHeader(
              chatName: 'Phantom Thieves',
              participants: Sender.values.where((s) => s != Sender.ren).toList(),
              fontFamily: _fontFamilies[_fontIndex],
            ),
          ),

          // Input bar
          Align(
            alignment: Alignment.bottomCenter,
            child: InputBar(onSend: _onSend),
          ),

          // ── DEBUG font picker ─────────────────────────────────────────
          Positioned(
            bottom: 90,
            left: 0,
            right: 0,
            child: _FontDebugBar(
              index: _fontIndex,
              labels: _fontLabels,
              onChanged: (i) => setState(() => _fontIndex = i),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Debug slider widget ────────────────────────────────────────────────────

class _FontDebugBar extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _FontDebugBar({
    required this.index,
    required this.labels,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          labels[index],
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
        Slider(
          value: index.toDouble(),
          min: 0,
          max: (labels.length - 1).toDouble(),
          divisions: labels.length - 1,
          activeColor: Colors.white,
          inactiveColor: Colors.white38,
          onChanged: (v) => onChanged(v.round()),
        ),
      ],
    );
  }
}
