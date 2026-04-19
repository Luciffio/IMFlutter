import 'dart:io';
import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';

// Large image bubble — Persona 5 IM photo style:
//   • full-width photo frame, slightly tilted, very thick black border
//   • image clipped to the inner quad
//   • small square portrait badge behind the frame at the bottom-right corner
class ImageBubble extends StatelessWidget {
  final Message message;
  final double hScale;
  final double vScale;
  final double alpha;

  const ImageBubble({
    super.key,
    required this.message,
    this.hScale = 1.0,
    this.vScale = 1.0,
    this.alpha = 1.0,
  });

  static const _kRotation = -0.078; // ≈ –4.5°
  static const _kBadgeSize = 78.0;
  // How many dp the frame overlaps the badge from the top
  static const _kBadgeOverlap = 44.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (ctx, constraints) {
      const margin = 12.0;
      // Extra top padding so the rotated frame (≈13 dp overflow at the
      // top-right corner) never bleeds into the 16 dp gap above and hides
      // the connecting-line shadow. 20 dp gives a comfortable 7 dp buffer.
      const topPad = 20.0;
      final frameW = constraints.maxWidth - margin * 2;
      final frameH = (frameW * 0.68).roundToDouble();
      final containerH = topPad + frameH + _kBadgeSize - _kBadgeOverlap;

      return Align(
        alignment: Alignment.center,
        child: SizedBox(
          width: frameW,
          height: containerH,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Badge drawn FIRST → behind the frame
              Positioned(
                right: 0,
                bottom: 0,
                child: _SenderBadge(sender: message.sender),
              ),
              // Frame drawn SECOND → in front, overlaps badge's top-left.
              // top: topPad ensures the rotation overflow stays within the item
              // and doesn't bleed into the gap above (where the shadow lives).
              Positioned(
                left: 0,
                top: topPad,
                child: _buildFrame(frameW, frameH),
              ),
            ],
          ),
        ),
      );
    });
  }

  // Bundled assets start with "assets/"; anything else is a file path from
  // the gallery (image_picker) and must be rendered with Image.file.
  Widget _imageFor(String path) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }

  Widget _buildFrame(double w, double h) {
    return Transform(
      transform: Matrix4.diagonal3Values(hScale, vScale, 1.0),
      alignment: Alignment.center,
      child: Transform.rotate(
        angle: _kRotation,
        alignment: Alignment.center,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(painter: const _FramePainter()),
              ),
              Positioned.fill(
                child: ClipPath(
                  clipper: const _FrameClipper(),
                  child: Opacity(
                    opacity: alpha.clamp(0.0, 1.0),
                    child: _imageFor(message.imagePath!),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sender badge ─────────────────────────────────────────────────────────────
// Small square in P5 style: thick black border, white fill, portrait face.

class _SenderBadge extends StatelessWidget {
  final Sender sender;
  const _SenderBadge({required this.sender});

  @override
  Widget build(BuildContext context) {
    const s = ImageBubble._kBadgeSize;
    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: const _BadgePainter())),
          Positioned.fill(
            child: ClipPath(
              clipper: const _BadgeClipper(),
              child: sender.portraitAsset != null
                  ? Image.asset(
                      sender.portraitAsset!,
                      fit: BoxFit.cover,
                      // bias upward so the face area is shown
                      alignment: const Alignment(0, -0.6),
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Frame painters / clipper ─────────────────────────────────────────────────

class _FramePainter extends CustomPainter {
  const _FramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow
    canvas.save();
    canvas.translate(10, 14);
    canvas.drawPath(
      _borderPath(w, h),
      Paint()..color = Colors.black.withAlpha(80),
    );
    canvas.restore();

    canvas.drawPath(_borderPath(w, h), Paint()..color = Colors.black);
  }

  Path _borderPath(double w, double h) => Path()
    ..moveTo(0, 8)
    ..lineTo(w - 10, 0)
    ..lineTo(w, h - 8)
    ..lineTo(10, h)
    ..close();

  @override
  bool shouldRepaint(_FramePainter old) => false;
}

class _FrameClipper extends CustomClipper<Path> {
  const _FrameClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    // ~13-16 dp thick border on all sides
    return Path()
      ..moveTo(13, 18)
      ..lineTo(w - 18, 12)
      ..lineTo(w - 13, h - 16)
      ..lineTo(16, h - 10)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

// ── Badge painters / clipper ──────────────────────────────────────────────────

class _BadgePainter extends CustomPainter {
  const _BadgePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Shadow
    canvas.save();
    canvas.translate(5, 7);
    canvas.drawPath(_outer(w, h), Paint()..color = Colors.black.withAlpha(80));
    canvas.restore();

    // Thick black outer border
    canvas.drawPath(_outer(w, h), Paint()..color = Colors.black);
    // White fill — portrait is rendered on top via ClipPath
    canvas.drawPath(_inner(w, h), Paint()..color = Colors.white);
  }

  // Outer quad — slight P5-style skew
  Path _outer(double w, double h) => Path()
    ..moveTo(0, 6)
    ..lineTo(w - 6, 0)
    ..lineTo(w, h - 5)
    ..lineTo(5, h)
    ..close();

  // Inner quad — ~10 dp inset → thick visible border
  Path _inner(double w, double h) => Path()
    ..moveTo(10, 14)
    ..lineTo(w - 13, 9)
    ..lineTo(w - 10, h - 12)
    ..lineTo(12, h - 7)
    ..close();

  @override
  bool shouldRepaint(_BadgePainter old) => false;
}

class _BadgeClipper extends CustomClipper<Path> {
  const _BadgeClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(10, 14)
      ..lineTo(w - 13, 9)
      ..lineTo(w - 10, h - 12)
      ..lineTo(12, h - 7)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
