import 'package:flutter/material.dart';

class PersonaProgressBar extends StatefulWidget {
  final double width;
  final double height;
  final Color trackColor;
  final Color fillColor;
  final Color borderColor;

  const PersonaProgressBar({
    super.key,
    this.width = 160,
    this.height = 10,
    this.trackColor = Colors.black,
    this.fillColor = const Color(0xFFF70000),
    this.borderColor = Colors.white,
  });

  @override
  State<PersonaProgressBar> createState() => _PersonaProgressBarState();
}

class _PersonaProgressBarState extends State<PersonaProgressBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 980),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _PersonaProgressPainter(
            progress: _controller.value,
            trackColor: widget.trackColor,
            fillColor: widget.fillColor,
            borderColor: widget.borderColor,
          ),
        ),
      ),
    );
  }
}

class _PersonaProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;
  final Color borderColor;

  const _PersonaProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
    required this.borderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..moveTo(0, 2)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 3, size.height - 1)
      ..lineTo(2, size.height)
      ..close();
    canvas.drawPath(outer, Paint()..color = borderColor);

    final inner = Path()
      ..moveTo(3, 4)
      ..lineTo(size.width - 4, 2)
      ..lineTo(size.width - 6, size.height - 3)
      ..lineTo(5, size.height - 2)
      ..close();
    canvas.drawPath(inner, Paint()..color = trackColor);

    canvas.save();
    canvas.clipPath(inner);
    final segmentWidth = size.width * 0.34;
    final x = -segmentWidth + (size.width + segmentWidth) * progress;
    final segment = Path()
      ..moveTo(x, 0)
      ..lineTo(x + segmentWidth, 0)
      ..lineTo(x + segmentWidth - 7, size.height)
      ..lineTo(x - 7, size.height)
      ..close();
    canvas.drawPath(segment, Paint()..color = fillColor);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PersonaProgressPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}

class PersonaLoadingMark extends StatelessWidget {
  final String? label;
  final double width;

  const PersonaLoadingMark({super.key, this.label, this.width = 160});

  @override
  Widget build(BuildContext context) {
    final text = label?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PersonaProgressBar(width: width),
        if (text != null && text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'OptimaNova',
              fontSize: 11,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ],
    );
  }
}
