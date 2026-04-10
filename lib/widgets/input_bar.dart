import 'dart:math' as math;
import 'package:flutter/material.dart';

// Persona 5-styled bottom input bar.
// Layout: [+ button] [text field──────────] [😊] [▶ send]
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
      padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomPad),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _PlusButton(onTap: () {}),
          const SizedBox(width: 8),
          Expanded(
            child: _InputField(controller: _ctrl, onSubmitted: (_) => _send()),
          ),
          const SizedBox(width: 8),
          _EmojiButton(onTap: () {}),
          const SizedBox(width: 6),
          _SendButton(onTap: _send),
        ],
      ),
    );
  }
}

// ── + Button ───────────────────────────────────────────────────────────────

class _PlusButton extends StatelessWidget {
  final VoidCallback onTap;
  const _PlusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 50,
        child: CustomPaint(painter: _PlusButtonPainter()),
      ),
    );
  }
}

class _PlusButtonPainter extends CustomPainter {
  static const _angle = -0.18; // ≈ –10° — makes it look delightfully crooked

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    // Rotate around center
    canvas.translate(w / 2, h / 2);
    canvas.rotate(_angle);
    canvas.translate(-w / 2, -h / 2);

    // Outer black box (slight skew)
    canvas.drawPath(
      Path()
        ..moveTo(3, 0)
        ..lineTo(w, 1)
        ..lineTo(w - 3, h)
        ..lineTo(0, h - 1)
        ..close(),
      Paint()..color = Colors.black,
    );

    // Inner white box
    canvas.drawPath(
      Path()
        ..moveTo(6, 3)
        ..lineTo(w - 3, 4)
        ..lineTo(w - 6, h - 3)
        ..lineTo(3, h - 4)
        ..close(),
      Paint()..color = Colors.white,
    );

    // "+" — two thick rectangles
    const arm = 9.0;
    const thick = 3.5;
    final cx = w / 2;
    final cy = h / 2;
    final bar = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTRB(cx - arm, cy - thick, cx + arm, cy + thick), bar);
    canvas.drawRect(Rect.fromLTRB(cx - thick, cy - arm, cx + thick, cy + arm), bar);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PlusButtonPainter old) => false;
}

// ── Input field ────────────────────────────────────────────────────────────

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onSubmitted;
  const _InputField({required this.controller, this.onSubmitted});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: CustomPaint(
        painter: _InputFieldPainter(),
        child: Padding(
          // Left extra for the skew, right mirror
          padding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
          child: Center(
            child: TextField(
              controller: controller,
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
              onSubmitted: onSubmitted,
            ),
          ),
        ),
      ),
    );
  }
}

class _InputFieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Parallelogram — top-left corner pushed right, bottom-left pushed left
    const skewTop = 6.0;
    const skewBot = 3.0;

    canvas.drawPath(
      Path()
        ..moveTo(skewTop, 0)
        ..lineTo(w, 0)
        ..lineTo(w - skewBot, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = Colors.black,
    );

    const b = 3.0;
    canvas.drawPath(
      Path()
        ..moveTo(skewTop + b, b)
        ..lineTo(w - b, b)
        ..lineTo(w - skewBot - b, h - b)
        ..lineTo(b, h - b)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_InputFieldPainter old) => false;
}

// ── Emoji button ───────────────────────────────────────────────────────────

class _EmojiButton extends StatelessWidget {
  final VoidCallback onTap;
  const _EmojiButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const SizedBox(
        width: 36,
        height: 36,
        child: Center(
          child: Text('😊', style: TextStyle(fontSize: 22)),
        ),
      ),
    );
  }
}

// ── Send button (right-pointing triangle inside a skewed box) ──────────────

class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  const _SendButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 50,
        height: 50,
        child: CustomPaint(painter: _SendButtonPainter()),
      ),
    );
  }
}

class _SendButtonPainter extends CustomPainter {
  static const _angle = 0.12; // ≈ +7° — slight tilt opposite to "+"

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.save();
    canvas.translate(w / 2, h / 2);
    canvas.rotate(_angle);
    canvas.translate(-w / 2, -h / 2);

    // Outer black box
    canvas.drawPath(
      Path()
        ..moveTo(0, 1)
        ..lineTo(w - 3, 0)
        ..lineTo(w, h - 1)
        ..lineTo(3, h)
        ..close(),
      Paint()..color = Colors.black,
    );

    // Inner white box
    canvas.drawPath(
      Path()
        ..moveTo(3, 4)
        ..lineTo(w - 6, 3)
        ..lineTo(w - 3, h - 4)
        ..lineTo(6, h - 3)
        ..close(),
      Paint()..color = Colors.white,
    );

    // Right-pointing triangle (▶)
    final cx = w / 2 + 1;
    final cy = h / 2;
    const half = 10.0;
    canvas.drawPath(
      Path()
        ..moveTo(cx - half * 0.65, cy - half)
        ..lineTo(cx + half, cy)
        ..lineTo(cx - half * 0.65, cy + half)
        ..close(),
      Paint()..color = Colors.black,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SendButtonPainter old) => false;
}
