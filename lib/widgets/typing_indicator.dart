import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/persona_colors.dart';

// Mirrors TypingIndicator.kt — speech bubble with 3 animated dots.
// Bubble path comes exactly from typing_bubble.xml (viewport 230×116, display 90×45dp).
class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scale;

  // -6..12 degrees, fixed for the lifetime of this widget
  final double _rotation = Random().nextDouble() * 18 - 6;

  bool _dot1 = false, _dot2 = false, _dot3 = false;
  bool _looping = true;

  @override
  void initState() {
    super.initState();

    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 116),
    );
    _scale = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.easeOutBack),
    );

    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _scaleCtrl.forward();
    });

    _runDotLoop();
  }

  Future<void> _runDotLoop() async {
    while (_looping && mounted) {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _dot1 = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _dot2 = true);
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _dot3 = true);
      await Future.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() => _dot1 = false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _dot2 = false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
      setState(() => _dot3 = false);
    }
  }

  @override
  void dispose() {
    _looping = false;
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Align(centerLeft) gives the SizedBox loose constraints so it stays
    // at exactly kAvatarWidth — otherwise ListView's tight-width constraint
    // forces it to full screen width and Center puts the bubble in the middle.
    return Align(
      alignment: Alignment.centerLeft,
      child: SizedBox(
        width: kAvatarWidth,
        height: kAvatarHeight,
        child: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Center(
          child: AnimatedBuilder(
            animation: _scale,
            builder: (_, child) => Transform.scale(
              scale: _scale.value,
              child: Transform.rotate(
                angle: _rotation * pi / 180,
                child: child,
              ),
            ),
            // Bubble is 90×45 dp (same ratio as the vector drawable)
            child: CustomPaint(
              size: const Size(90, 45),
              painter: _BubblePainter(
                dot1: _dot1,
                dot2: _dot2,
                dot3: _dot3,
              ),
            ),
          ),
        ),
      ),
    ), // SizedBox
    ); // Align
  }
}

class _BubblePainter extends CustomPainter {
  final bool dot1, dot2, dot3;
  const _BubblePainter({
    required this.dot1,
    required this.dot2,
    required this.dot3,
  });

  // Viewport from typing_bubble.xml: 230 × 116
  static const _vw = 230.0;
  static const _vh = 116.0;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / _vw;
    final sy = size.height / _vh;

    double x(double v) => v * sx;
    double y(double v) => v * sy;

    // Exact path from typing_bubble.xml
    final bubble = Path()
      ..moveTo(x(0), y(113.32))
      ..lineTo(x(57.06), y(69.28))
      ..lineTo(x(62.57), y(81.2))
      ..lineTo(x(71.44), y(68.68))
      ..lineTo(x(58.43), y(34.59))
      ..lineTo(x(222.6), y(0))
      ..lineTo(x(229.6), y(98.05))
      ..lineTo(x(88.69), y(115.1))
      ..lineTo(x(84.25), y(102.98))
      ..lineTo(x(52.92), y(114.9))
      ..lineTo(x(47.89), y(95.68))
      ..close();

    canvas.drawPath(bubble, Paint()..color = kPersonaDarkRed);

    // Dots — positioned at display-space (center.x - 4dp, center.y),
    // spaced 12dp apart. Display size is 90×45, so:
    //   center = (45, 22.5) in display dp → (45/90*230, 22.5/45*116) in viewport
    //   dot1_left = center.x - 4 = 41dp
    const dot1X = 41.0 / 90.0 * _vw; // ≈ 104.9 vp
    const dotSpacing = 12.0 / 90.0 * _vw; // ≈ 30.7 vp
    const dotCY = 22.5 / 45.0 * _vh; // ≈ 58 vp
    const dotW = 6.5 / 90.0 * _vw; // ≈ 16.2 vp  (dot ~6dp wide)
    const dotH = 6.5 / 45.0 * _vh; // ≈ 16.3 vp

    final dotPaint = Paint()..color = kPersonaRed;

    if (dot1) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x(dot1X), y(dotCY)), width: x(dotW), height: y(dotH)),
        dotPaint,
      );
    }
    if (dot2) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x(dot1X + dotSpacing), y(dotCY)), width: x(dotW), height: y(dotH)),
        dotPaint,
      );
    }
    if (dot3) {
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x(dot1X + dotSpacing * 2), y(dotCY)), width: x(dotW), height: y(dotH)),
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) =>
      old.dot1 != dot1 || old.dot2 != dot2 || old.dot3 != dot3;
}
