import 'package:flutter/material.dart';

class PersonaProgressBar extends StatefulWidget {
  final double width;
  final double height;
  final Color trackColor;
  final Color fillColor;
  final Color borderColor;
  final double? value;

  const PersonaProgressBar({
    super.key,
    this.width = 160,
    this.height = 10,
    this.trackColor = Colors.black,
    this.fillColor = const Color(0xFFF70000),
    this.borderColor = Colors.white,
    this.value,
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
    );
    if (widget.value == null) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant PersonaProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == null && oldWidget.value != null) {
      _controller.repeat();
    } else if (widget.value != null && oldWidget.value == null) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    if (value != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: CustomPaint(
          painter: _PersonaProgressPainter(
            progress: value.clamp(0.0, 1.0),
            isDeterminate: true,
            trackColor: widget.trackColor,
            fillColor: widget.fillColor,
            borderColor: widget.borderColor,
          ),
        ),
      );
    }
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _PersonaProgressPainter(
            progress: _controller.value,
            isDeterminate: false,
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
  final bool isDeterminate;
  final Color trackColor;
  final Color fillColor;
  final Color borderColor;

  const _PersonaProgressPainter({
    required this.progress,
    required this.isDeterminate,
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
    final segmentWidth = isDeterminate
        ? size.width * progress
        : size.width * 0.34;
    final x = isDeterminate
        ? 0.0
        : -segmentWidth + (size.width + segmentWidth) * progress;
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
      oldDelegate.isDeterminate != isDeterminate ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.fillColor != fillColor ||
      oldDelegate.borderColor != borderColor;
}

class PersonaLoadingMark extends StatelessWidget {
  final String? label;
  final double width;
  final double? progress;

  const PersonaLoadingMark({
    super.key,
    this.label,
    this.width = 160,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final text = label?.trim();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        PersonaProgressBar(width: width, value: progress),
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
