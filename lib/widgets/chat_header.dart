import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'persona_avatar.dart';

class ChatHeader extends StatelessWidget {
  final String chatName;
  final List<Sender> participants;

  const ChatHeader({
    super.key,
    required this.chatName,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final topPad = mq.padding.top;
    final headerH = mq.size.height * 0.20; // 20 % of screen

    // Avatar height fills most of the usable header area
    final avatarH = (headerH - topPad - 12).clamp(56.0, 140.0);
    final avatarW = avatarH * (kAvatarWidth / kAvatarHeight);
    final avatarOverlap = avatarW * 0.22;

    final stripW = participants.isEmpty
        ? 0.0
        : avatarW + (avatarW - avatarOverlap) * (participants.length - 1);

    return SizedBox(
      height: headerH,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, topPad + 8, 12, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── Chat name — big stroked text, no background ───────────────
            Expanded(
              child: _StrokedText(
                text: chatName,
                fontSize: (avatarH * 0.38).clamp(20.0, 36.0),
              ),
            ),

            const SizedBox(width: 10),

            // ── Overlapping avatars ───────────────────────────────────────
            SizedBox(
              width: stripW,
              height: avatarH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < participants.length; i++)
                    Positioned(
                      left: i * (avatarW - avatarOverlap),
                      top: 0,
                      child: _MiniAvatar(
                        sender: participants[i],
                        w: avatarW,
                        h: avatarH,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Big white text with black stroke ────────────────────────────────────────

class _StrokedText extends StatelessWidget {
  final String text;
  final double fontSize;

  const _StrokedText({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontFamily: 'OptimaNova',
      fontWeight: FontWeight.w900,
      fontSize: fontSize,
      height: 1.15,
    );

    return Stack(
      children: [
        // Black stroke layer (drawn first, under the fill)
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6
              ..strokeJoin = StrokeJoin.round
              ..color = Colors.black,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        // White fill layer
        Text(
          text,
          style: base.copyWith(color: Colors.white),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ── Mini avatar — PersonaAvatar scaled to fill the given slot ───────────────

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
