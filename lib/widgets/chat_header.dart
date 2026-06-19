import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'persona_avatar.dart';

// Fixed avatar dimensions — big enough to be readable, small enough to leave
// room for the chat name on the left.
const _avatarH = 56.0;
const _avatarW = _avatarH * kAvatarWidth / kAvatarHeight; // ≈ 68 dp
const _avatarOverlap = 14.0;

class ChatHeader extends StatefulWidget {
  final String chatName;
  final List<Sender> participants;
  final VoidCallback onBack;

  const ChatHeader({
    super.key,
    required this.chatName,
    required this.participants,
    required this.onBack,
  });

  @override
  State<ChatHeader> createState() => _ChatHeaderState();
}

class _ChatHeaderState extends State<ChatHeader> {
  bool _showBack = false;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    final stripW = widget.participants.isEmpty
        ? 0.0
        : _avatarW +
              (_avatarW - _avatarOverlap) * (widget.participants.length - 1);

    return SizedBox(
      height: topPad + 132,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOut,
            left: _showBack ? 64 : 12,
            right: stripW + 22,
            top: topPad + 10,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _showBack = !_showBack),
              child: Transform(
                alignment: Alignment.centerLeft,
                transform: Matrix4.identity()..rotateZ(-0.13),
                child: _StrokedText(
                  text: widget.chatName,
                  fontSize: _fontSizeFor(widget.chatName),
                  fontFamily: 'Fruktur',
                ),
              ),
            ),
          ),
          Positioned(
            right: 12,
            top: topPad + 8,
            child: SizedBox(
              width: stripW,
              height: _avatarH,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (int i = 0; i < widget.participants.length; i++)
                    Positioned(
                      left: i * (_avatarW - _avatarOverlap),
                      top: 0,
                      child: _MiniAvatar(
                        sender: widget.participants[i],
                        w: _avatarW,
                        h: _avatarH,
                      ),
                    ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 8,
            top: topPad + 6,
            child: IgnorePointer(
              ignoring: !_showBack,
              child: AnimatedOpacity(
                opacity: _showBack ? 1 : 0,
                duration: const Duration(milliseconds: 120),
                child: _HeaderBackButton(onTap: widget.onBack),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _fontSizeFor(String title) {
    final length = title.trim().length;
    if (length <= 12) return 40;
    if (length <= 20) return 34;
    if (length <= 28) return 29;
    return 25;
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

class _HeaderBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: CustomPaint(
        painter: const _HeaderBackButtonPainter(),
        child: const SizedBox(
          width: 48,
          height: 40,
          child: Center(
            child: Icon(Icons.arrow_back, color: Colors.black, size: 27),
          ),
        ),
      ),
    );
  }
}

class _HeaderBackButtonPainter extends CustomPainter {
  const _HeaderBackButtonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..moveTo(2, size.height * 0.48)
      ..lineTo(15, 2)
      ..lineTo(size.width - 3, 5)
      ..lineTo(size.width - 7, size.height - 3)
      ..lineTo(14, size.height - 6)
      ..close();
    canvas.drawPath(outer, Paint()..color = Colors.black);

    final inner = Path()
      ..moveTo(7, size.height * 0.49)
      ..lineTo(17, 7)
      ..lineTo(size.width - 9, 9)
      ..lineTo(size.width - 12, size.height - 8)
      ..lineTo(17, size.height - 10)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_HeaderBackButtonPainter oldDelegate) => false;
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
