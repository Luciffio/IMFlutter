import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';

// Mirrors connectingLineModifier.kt
// Painter knows both senders so it can compute x-offsets from size.width in paint().
class ConnectingLinePainter extends CustomPainter {
  final bool currentIsRen;
  final Offset currentLineLeft;
  final Offset currentLineRight;
  final bool nextIsRen;
  final Offset nextLineLeft;
  final Offset nextLineRight;
  final double lineProgress;

  const ConnectingLinePainter({
    required this.currentIsRen,
    required this.currentLineLeft,
    required this.currentLineRight,
    required this.nextIsRen,
    required this.nextLineLeft,
    required this.nextLineRight,
    required this.lineProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Top offset: for Ren messages, shift x so the line appears on the right side
    final topDx = currentIsRen ? size.width - kRenMessageCenterX * 2 : 0.0;
    final topLeft = currentLineLeft + Offset(topDx, 0);
    final topRight = currentLineRight + Offset(topDx, 0);

    // Bottom: next item starts at current item bottom + spacing
    final yShift = size.height + kEntrySpacing;
    final bottomDx = nextIsRen ? size.width - kRenMessageCenterX * 2 : 0.0;
    final bottomLeft = nextLineLeft + Offset(bottomDx, yShift);
    final bottomRight = nextLineRight + Offset(bottomDx, yShift);

    final currBL = Offset.lerp(topLeft, bottomLeft, lineProgress)!;
    final currBR = Offset.lerp(topRight, bottomRight, lineProgress)!;

    final path = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(currBR.dx, currBR.dy)
      ..lineTo(currBL.dx, currBL.dy)
      ..close();

    // Shadow: no blur, semi-transparent
    canvas.save();
    canvas.translate(6, 10);
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withAlpha(80),
    );
    canvas.restore();

    // Main black line
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(ConnectingLinePainter old) =>
      old.lineProgress != lineProgress ||
      old.currentLineLeft != currentLineLeft ||
      old.currentLineRight != currentLineRight ||
      old.nextLineLeft != nextLineLeft ||
      old.nextLineRight != nextLineRight;
}
