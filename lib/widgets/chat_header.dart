import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'persona_avatar.dart';

// Fixed avatar dimensions — big enough to be readable, small enough to leave
// room for the chat name on the left.
const _avatarH = 56.0;
const _avatarW = _avatarH * kAvatarWidth / kAvatarHeight; // ≈ 68 dp
const _avatarOverlap = 14.0;

class ChatHeader extends StatelessWidget {
  // ignore: unused_field — will be dynamic once backend provides chat info
  final String chatName;
  final List<Sender> participants;
  const ChatHeader({
    super.key,
    required this.chatName,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    // Total width of the overlapping avatar strip
    final stripW = participants.isEmpty
        ? 0.0
        : _avatarW + (_avatarW - _avatarOverlap) * (participants.length - 1);

    return Padding(
      padding: EdgeInsets.fromLTRB(12, topPad + 8, 12, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Chat name — left, big stroked text, no background ─────────
          Expanded(
            child: Transform(
              alignment: Alignment.centerLeft,
              transform: Matrix4.identity()
                ..translate(20.0, 28.0)  // shifted right + lower
                ..rotateZ(-0.175),        // –10°
              child: const _StrokedText(
                text: 'Phantom Thieves',
                fontSize: 48,
                fontFamily: 'Fruktur',
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Avatar strip — right ──────────────────────────────────────
          SizedBox(
            width: stripW,
            height: _avatarH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < participants.length; i++)
                  Positioned(
                    left: i * (_avatarW - _avatarOverlap),
                    top: 0,
                    child: _MiniAvatar(
                      sender: participants[i],
                      w: _avatarW,
                      h: _avatarH,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stroked text ─────────────────────────────────────────────────────────────

class _StrokedText extends StatelessWidget {
  final String text;
  final double fontSize;
  final String fontFamily;

  const _StrokedText({
    required this.text,
    required this.fontSize,
    required this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: fontFamily,
      fontWeight: FontWeight.w900,
      height: 1.15,
    );

    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            fontSize: fontSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 5
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          text,
          style: base.copyWith(fontSize: fontSize, color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Mini avatar ───────────────────────────────────────────────────────────────

class _MiniAvatar extends StatelessWidget {
  final Sender sender;
  final double w;
  final double h;

  const _MiniAvatar({required this.sender, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      height: h,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: kAvatarWidth,
          height: kAvatarHeight,
          child: PersonaAvatar(sender: sender),
        ),
      ),
    );
  }
}
