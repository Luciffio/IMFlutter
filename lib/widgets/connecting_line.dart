import 'package:flutter/material.dart';
import '../theme/persona_colors.dart';

// Mirrors connectingLineModifier.kt
// Painter knows both senders so it can compute x-offsets from size.width in paint().
class ConnectingLinePainter extends CustomPainter {
  final bool currentIsRen;
  final bool currentIsSticker;
  final Offset currentLineLeft;
  final Offset currentLineRight;
  final bool nextIsRen;
  final bool nextIsSticker;
  final Offset nextLineLeft;
  final Offset nextLineRight;
  final double lineProgress;

  const ConnectingLinePainter({
    required this.currentIsRen,
    this.currentIsSticker = false,
    required this.currentLineLeft,
    required this.currentLineRight,
    required this.nextIsRen,
    this.nextIsSticker = false,
    required this.nextLineLeft,
    required this.nextLineRight,
    required this.lineProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final topDx = currentIsRen ? size.width - kRenMessageCenterX * 2 : 0.0;
    final topLeft = currentLineLeft + Offset(topDx, 0);
    final topRight = currentLineRight + Offset(topDx, 0);

    final yShift = size.height + kEntrySpacing;
    final bottomDx = nextIsRen ? size.width - kRenMessageCenterX * 2 : 0.0;
    final finalBL = nextLineLeft + Offset(bottomDx, yShift);
    final finalBR = nextLineRight + Offset(bottomDx, yShift);

    final path = (currentIsSticker || nextIsSticker)
        ? _buildElbowPath(topLeft, topRight, finalBL, finalBR, size)
        : _buildStraightPath(topLeft, topRight, finalBL, finalBR);

    canvas.save();
    canvas.translate(6, 10);
    canvas.drawPath(path, Paint()..color = Colors.black.withAlpha(80));
    canvas.restore();

    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  /// Normal straight trapezoid (original behaviour).
  Path _buildStraightPath(Offset tl, Offset tr, Offset bl, Offset br) {
    final currBL = Offset.lerp(tl, bl, lineProgress)!;
    final currBR = Offset.lerp(tr, br, lineProgress)!;
    return Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(currBR.dx, currBR.dy)
      ..lineTo(currBL.dx, currBL.dy)
      ..close();
  }

  /// Sticker-aware path.  The diagonal portion spans the full height of the
  /// non-sticker entry so the band stays thick and visible.  Only the segment
  /// that overlaps a sticker is forced to a vertical strip in the avatar column.
  ///
  /// When the non-sticker entry is too short for a proper diagonal (e.g. a Ren
  /// reply next to a sticker) we fall back to the standard straight trapezoid —
  /// the sticker's opaque image + avatar hide most of the line behind them.
  Path _buildElbowPath(
      Offset tl, Offset tr, Offset finalBL, Offset finalBR, Size size) {
    // Both entries are stickers → both sit in the avatar column → plain line.
    if (currentIsSticker && nextIsSticker) {
      return _buildStraightPath(tl, tr, finalBL, finalBR);
    }

    // Check whether the diagonal has enough vertical room to look natural.
    // A Ren reply is only ~56 dp tall — forcing an elbow produces a nearly
    // horizontal sliver that looks worse than a straight line behind the
    // sticker.  Threshold 0.4 ≈ 22° minimum angle.
    final midTopX = (tl.dx + tr.dx) / 2;
    final midBotX = (finalBL.dx + finalBR.dx) / 2;
    final hDist = (midTopX - midBotX).abs();

    if (hDist > 0) {
      final diagVDist = currentIsSticker
          ? finalBL.dy - size.height       // diagonal below the sticker
          : size.height + kEntrySpacing - tl.dy; // diagonal above the sticker
      if (diagVDist / hDist < 0.4) {
        return _buildStraightPath(tl, tr, finalBL, finalBR);
      }
    }

    final yShift = size.height + kEntrySpacing;
    final totalY = finalBL.dy - tl.dy;
    final currentY = tl.dy + totalY * lineProgress;

    if (currentIsSticker) {
      // ── vertical inside the sticker, then a wide diagonal below it ──
      final elbowY = size.height; // bottom edge of the sticker widget

      if (currentY <= elbowY) {
        // Still growing the vertical strip
        return Path()
          ..moveTo(tl.dx, tl.dy)
          ..lineTo(tr.dx, tr.dy)
          ..lineTo(tr.dx, currentY)
          ..lineTo(tl.dx, currentY)
          ..close();
      }

      // Vertical complete — growing diagonal from elbow toward next entry
      final denom = finalBL.dy - elbowY;
      final diagT = denom > 0 ? (currentY - elbowY) / denom : 1.0;
      final cBL = Offset(tl.dx + (finalBL.dx - tl.dx) * diagT, currentY);
      final cBR = Offset(tr.dx + (finalBR.dx - tr.dx) * diagT, currentY);
      return Path()
        ..moveTo(tl.dx, tl.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(tr.dx, elbowY)
        ..lineTo(cBR.dx, cBR.dy)
        ..lineTo(cBL.dx, cBL.dy)
        ..lineTo(tl.dx, elbowY)
        ..close();
    }

    // ── wide diagonal down to the sticker boundary, then vertical inside it ──
    final elbowY = yShift; // top edge of the next (sticker) widget
    final denom = elbowY - tl.dy;

    if (currentY <= elbowY) {
      // Growing diagonal — a standard trapezoid aimed at the avatar column
      final diagT = denom > 0 ? (currentY - tl.dy) / denom : 1.0;
      final cBL = Offset(tl.dx + (finalBL.dx - tl.dx) * diagT, currentY);
      final cBR = Offset(tr.dx + (finalBR.dx - tr.dx) * diagT, currentY);
      return Path()
        ..moveTo(tl.dx, tl.dy)
        ..lineTo(tr.dx, tr.dy)
        ..lineTo(cBR.dx, cBR.dy)
        ..lineTo(cBL.dx, cBL.dy)
        ..close();
    }

    // Diagonal complete — growing vertical inside the sticker
    return Path()
      ..moveTo(tl.dx, tl.dy)
      ..lineTo(tr.dx, tr.dy)
      ..lineTo(finalBR.dx, elbowY)
      ..lineTo(finalBR.dx, currentY)
      ..lineTo(finalBL.dx, currentY)
      ..lineTo(finalBL.dx, elbowY)
      ..close();
  }

  @override
  bool shouldRepaint(ConnectingLinePainter old) =>
      old.lineProgress != lineProgress ||
      old.currentLineLeft != currentLineLeft ||
      old.currentLineRight != currentLineRight ||
      old.nextLineLeft != nextLineLeft ||
      old.nextLineRight != nextLineRight ||
      old.currentIsSticker != currentIsSticker ||
      old.nextIsSticker != nextIsSticker;
}
