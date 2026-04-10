import 'package:flutter/material.dart';

// Mirrors Reply.kt:
// Box(fillMaxWidth, CenterEnd) { Text(drawWithCache { bubble based on Text's OWN size }) }
// The bubble is sized to the TEXT content, NOT the full screen width.
// Full-screen width only applies when text is long enough to wrap.
class ReplyBubble extends StatelessWidget {
  final String text;
  final double messageHorizontalScale;
  final double messageVerticalScale;
  final double messageTextAlpha;

  const ReplyBubble({
    super.key,
    required this.text,
    this.messageHorizontalScale = 1.0,
    this.messageVerticalScale = 1.0,
    this.messageTextAlpha = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: LayoutBuilder(builder: (ctx, constraints) {
        return Align(
          alignment: Alignment.centerRight,
          // ConstrainedBox ensures text wraps at maxWidth rather than going infinite
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth),
            child: CustomPaint(
              painter: _ReplyBubblePainter(
                hScale: messageHorizontalScale,
                vScale: messageVerticalScale,
              ),
              // CustomPaint sizes itself to its child — i.e. text + padding
              child: Opacity(
                opacity: messageTextAlpha.clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.only(
                      left: 44, top: 20, right: 40, bottom: 20),
                  child: Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontFamily: 'OptimaNova',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ReplyBubblePainter extends CustomPainter {
  final double hScale;
  final double vScale;

  const _ReplyBubblePainter({required this.hScale, required this.vScale});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Scale pivot: right-center (mirrors Compose pivot = Offset(size.width, size.center.y))
    canvas.save();
    canvas.translate(w, h / 2);
    canvas.scale(hScale, vScale);
    canvas.translate(-w, -h / 2);

    // Outer black box
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w - 35, 4)
        ..lineTo(w - 10.7, h - 6.6)
        ..lineTo(35.5, h)
        ..close(),
      Paint()..color = Colors.black,
    );

    // Outer black stem
    canvas.drawPath(
      Path()
        ..moveTo(w - 37.6, h - 42.3)
        ..lineTo(w - 20.8, h - 30.2)
        ..lineTo(w - 19.4, h - 36.8)
        ..lineTo(w, h - 19.6)
        ..lineTo(w - 10.3, h - 19.6)
        ..lineTo(w - 12, h - 12.3)
        ..lineTo(w - 27.6, h - 15.2)
        ..close(),
      Paint()..color = Colors.black,
    );

    // Inner white stem
    canvas.drawPath(
      Path()
        ..moveTo(w - 33.1, h - 33.2)
        ..lineTo(w - 19.3, h - 26.3)
        ..lineTo(w - 16.4, h - 31.6)
        ..lineTo(w - 4.2, h - 21)
        ..lineTo(w - 12.4, h - 23.4)
        ..lineTo(w - 14, h - 17.2)
        ..lineTo(w - 28.6, h - 21.2)
        ..close(),
      Paint()..color = Colors.white,
    );

    // Inner white box
    canvas.drawPath(
      Path()
        ..moveTo(12, 5)
        ..lineTo(w - 36, 9.5)
        ..lineTo(w - 16.4, h - 11.7)
        ..lineTo(36.5, h - 3.5)
        ..close(),
      Paint()..color = Colors.white,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_ReplyBubblePainter old) =>
      old.hScale != hScale || old.vScale != vScale;
}
