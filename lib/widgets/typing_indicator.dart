import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/persona_colors.dart';

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scale;

  final double _rotation = Random().nextDouble() * 18 - 6;
  bool _dot1 = false;
  bool _dot2 = false;
  bool _dot3 = false;
  bool _looping = true;

  double get _rotationRadians => _rotation * pi / 180;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 116),
    );
    _scale = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutBack),
    );

    Future<void>.delayed(const Duration(milliseconds: 180), () {
      if (mounted) _scaleController.forward();
    });
    _runDotLoop();
  }

  Future<void> _runDotLoop() async {
    while (_looping && mounted) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _dot1 = true);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _dot2 = true);

      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      setState(() => _dot3 = true);

      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (!mounted) return;
      setState(() {
        _dot1 = false;
        _dot2 = false;
        _dot3 = false;
      });
    }
  }

  @override
  void dispose() {
    _looping = false;
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              builder: (context, child) => Transform.scale(
                scale: _scale.value,
                child: Transform.rotate(angle: _rotationRadians, child: child),
              ),
              child: SizedBox(
                width: 90,
                height: 45,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const CustomPaint(painter: _BubblePainter()),
                    Transform.rotate(
                      angle: -_rotationRadians,
                      child: CustomPaint(
                        painter: _DotsPainter(
                          dot1: _dot1,
                          dot2: _dot2,
                          dot3: _dot3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePainter extends CustomPainter {
  const _BubblePainter();

  static const _viewportWidth = 230.0;
  static const _viewportHeight = 116.0;

  @override
  void paint(Canvas canvas, Size size) {
    final scaleX = size.width / _viewportWidth;
    final scaleY = size.height / _viewportHeight;

    double x(double value) => value * scaleX;
    double y(double value) => value * scaleY;

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
  }

  @override
  bool shouldRepaint(_BubblePainter oldDelegate) => false;
}

class _DotsPainter extends CustomPainter {
  final bool dot1;
  final bool dot2;
  final bool dot3;

  const _DotsPainter({
    required this.dot1,
    required this.dot2,
    required this.dot3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 3.2;
    const spacing = 12.0;
    final center = Offset(size.width * 0.58, size.height * 0.5);
    final paint = Paint()..color = kPersonaRed;

    if (dot1) canvas.drawCircle(center.translate(-spacing, 0), radius, paint);
    if (dot2) canvas.drawCircle(center, radius, paint);
    if (dot3) canvas.drawCircle(center.translate(spacing, 0), radius, paint);
  }

  @override
  bool shouldRepaint(_DotsPainter oldDelegate) =>
      oldDelegate.dot1 != dot1 ||
      oldDelegate.dot2 != dot2 ||
      oldDelegate.dot3 != dot3;
}
