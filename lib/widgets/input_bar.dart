import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

              // Custom emoji icon
              GestureDetector(
                onTap: () {},
                child: SvgPicture.asset(
                  'assets/icons/smile.svg',
                  width: 44,
                  height: 44,
                ),
              ),

              const SizedBox(width: 10),

              // Right-pointing triangle send button
              GestureDetector(
                onTap: _send,
                child: const SizedBox(
                  width: 30,
                  height: 30,
                  child: Padding(
                    padding: EdgeInsets.all(6),
                    child: CustomPaint(painter: _TrianglePainter()),
                  ),
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
// Shape: \------|
//   Left edge  — diagonal \ (top-left pushed right by skew, bottom-left at 0)
//   Right edge — straight vertical | (same x on top and bottom)
//   Right side — 10 % narrower: 5 % inset from top, 5 % inset from bottom

class _BarPainter extends CustomPainter {
  const _BarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const skew = 8.0;          // how far the top-left corner is pushed right
    final inset = h * 0.05;   // 5 % trim on each side → 10 % total at right edge

    // Black outline
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)         // TL — flush left at top   ← \ starts here
        ..lineTo(w, inset)     // TR — right edge 5 % down
        ..lineTo(w, h - inset) // BR — right edge 5 % up (vertical |)
        ..lineTo(skew, h)      // BL — pushed right at bottom  \ ends here
        ..close(),
      Paint()..color = Colors.black,
    );

    // White fill (3 px border)
    const b = 3.0;
    canvas.drawPath(
      Path()
        ..moveTo(b, b)
        ..lineTo(w - b, inset + b)
        ..lineTo(w - b, h - inset - b)
        ..lineTo(skew + b, h - b)
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
      ..strokeWidth = 5.5
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

    // Smile — minimal short arc, just a gentle curve
    final smileRect = Rect.fromCenter(
      center: Offset(cx, cy + r * 0.22),
      width: r * 0.72,
      height: r * 0.38,
    );
    canvas.drawArc(smileRect, 0.1, math.pi - 0.2, false, stroke);
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
