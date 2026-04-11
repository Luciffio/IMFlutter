import 'dart:math' as math;
import 'package:flutter/material.dart';

// One continuous Persona 5-styled bar:
//   black outer parallelogram → white inner → [+] [text field] [face] [▶]
class InputBar extends StatefulWidget {
  final ValueChanged<String>? onSend;
  const InputBar({super.key, this.onSend});

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _ctrl = TextEditingController();

  void _send() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _ctrl.clear();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomPad),
      child: CustomPaint(
        painter: const _BarPainter(),
        child: SizedBox(
          height: 54,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: 14),

              // Crooked "+"
              GestureDetector(
                onTap: () {},
                child: Transform.rotate(
                  angle: -0.22, // ≈ –12.6° — pleasantly crooked
                  child: const SizedBox(
                    width: 26,
                    height: 26,
                    child: CustomPaint(painter: _PlusPainter()),
                  ),
                ),
              ),

              const SizedBox(width: 14),

              // Text field — takes all remaining space
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 14,
                    fontFamily: 'OptimaNova',
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'Message...',
                    hintStyle: TextStyle(
                      color: Colors.black38,
                      fontSize: 14,
                      fontFamily: 'OptimaNova',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  onSubmitted: (_) => _send(),
                ),
              ),

              const SizedBox(width: 12),

              // Stylized emoji face
              GestureDetector(
                onTap: () {},
                child: const SizedBox(
                  width: 32,
                  height: 32,
                  child: CustomPaint(painter: _FacePainter()),
                ),
              ),

              const SizedBox(width: 10),

              // Right-pointing triangle send button
              GestureDetector(
                onTap: _send,
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: CustomPaint(painter: _TrianglePainter()),
                ),
              ),

              const SizedBox(width: 14),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Single bar background ──────────────────────────────────────────────────
//
// Slight parallelogram skew — same language as the chat bubbles.

class _BarPainter extends CustomPainter {
  const _BarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const skew = 5.0; // top edge shifted right by this much

    // Black outline
    canvas.drawPath(
      Path()
        ..moveTo(skew, 0)
        ..lineTo(w, 0)
        ..lineTo(w - skew, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = Colors.black,
    );

    // White fill (inset 3 px on every side)
    const b = 3.0;
    canvas.drawPath(
      Path()
        ..moveTo(skew + b, b)
        ..lineTo(w - b, b)
        ..lineTo(w - skew - b, h - b)
        ..lineTo(b, h - b)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) => false;
}

// ── "+" — two stroked lines, drawn with square caps ────────────────────────

class _PlusPainter extends CustomPainter {
  const _PlusPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final p = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(Offset(0, h / 2), Offset(w, h / 2), p); // horizontal
    canvas.drawLine(Offset(w / 2, 0), Offset(w / 2, h), p); // vertical
  }

  @override
  bool shouldRepaint(_PlusPainter old) => false;
}

// ── Stylized smiley face (circle + dot eyes + arc smile) ───────────────────

class _FacePainter extends CustomPainter {
  const _FacePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = math.min(w, h) / 2 - 1.5;

    final stroke = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    final fill = Paint()..color = Colors.black;

    // Circle
    canvas.drawCircle(Offset(cx, cy), r, stroke);

    // Eyes — small filled circles
    final eyeR = r * 0.11;
    canvas.drawCircle(Offset(cx - r * 0.32, cy - r * 0.18), eyeR, fill);
    canvas.drawCircle(Offset(cx + r * 0.32, cy - r * 0.18), eyeR, fill);

    // Smile arc — bottom half of an ellipse
    final smileRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.08),
      width: r * 1.1,
      height: r * 0.72,
    );
    // startAngle: just past 3 o'clock going clockwise → bottom arc
    canvas.drawArc(smileRect, 0.25, math.pi - 0.5, false, stroke);
  }

  @override
  bool shouldRepaint(_FacePainter old) => false;
}

// ── Right-pointing filled triangle ─────────────────────────────────────────

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(w, h / 2)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(_TrianglePainter old) => false;
}
