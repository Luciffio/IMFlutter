import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/message.dart';
import 'persona_progress.dart';

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
    return LayoutBuilder(
      builder: (ctx, constraints) {
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: frameW,
                  height: containerH,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Badge drawn FIRST → behind the frame
                      if (_hasSenderBadge)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: _SenderBadge(message: message),
                        ),
                      // Frame drawn SECOND → in front, overlaps badge's top-left.
                      // top: topPad ensures the rotation overflow stays within the item
                      // and doesn't bleed into the gap above (where the shadow lives).
                      Positioned(
                        left: 0,
                        top: topPad,
                        child: Semantics(
                          button: true,
                          label: 'Open image',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: message.imagePaths.length == 1
                                ? () => _openFullScreen(
                                    context,
                                    message.imagePaths.first,
                                  )
                                : null,
                            child: _buildFrame(context, frameW, frameH),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (message.text.trim().isNotEmpty)
                  _ImageCaption(message: message),
              ],
            ),
          ),
        );
      },
    );
  }

  bool get _hasSenderBadge {
    final avatar = message.avatarPath;
    final label = message.avatarLabel;
    return message.sender.portraitAsset != null ||
        (avatar != null && avatar.isNotEmpty) ||
        (label != null && label.trim().isNotEmpty);
  }

  // Bundled assets start with "assets/"; anything else is a file path from
  // the gallery (image_picker) and must be rendered with Image.file.
  Widget _imageFor(String path) {
    return _renderImage(path, fit: BoxFit.cover);
  }

  void _openFullScreen(BuildContext context, String imagePath) {
    Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 150),
        pageBuilder: (_, _, _) => _FullScreenImageViewer(imagePath: imagePath),
        transitionsBuilder: (_, animation, _, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween(begin: 0.94, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrame(BuildContext context, double w, double h) {
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
                    child: message.imagePaths.isEmpty
                        ? const _MediaLoadingPlaceholder(label: 'LOADING')
                        : message.imagePaths.length > 1
                        ? _AlbumGrid(
                            paths: message.imagePaths,
                            onOpen: (path) => _openFullScreen(context, path),
                          )
                        : _imageFor(message.imagePaths.first),
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

class _MediaLoadingPlaceholder extends StatelessWidget {
  final String label;

  const _MediaLoadingPlaceholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF171717),
      child: Center(
        child: SizedBox(
          width: 150,
          child: PersonaLoadingMark(label: label, width: 132),
        ),
      ),
    );
  }
}

class _AlbumGrid extends StatelessWidget {
  final List<String> paths;
  final ValueChanged<String> onOpen;

  const _AlbumGrid({required this.paths, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final visible = paths.take(4).toList();
    return GridView.builder(
      padding: EdgeInsets.zero,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: visible.length,
      itemBuilder: (context, index) {
        final path = visible[index];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onOpen(path),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _renderImage(path, fit: BoxFit.cover),
              if (index == 3 && paths.length > 4)
                ColoredBox(
                  color: Colors.black54,
                  child: Center(
                    child: Text(
                      '+${paths.length - 3}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'OptimaNova',
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ImageCaption extends StatelessWidget {
  final Message message;

  const _ImageCaption({required this.message});

  @override
  Widget build(BuildContext context) {
    final outgoing = message.isOutgoing;
    final foreground = outgoing ? Colors.black : Colors.white;
    final background = outgoing ? Colors.white : Colors.black;
    final border = outgoing ? Colors.black : Colors.white;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
      child: Align(
        alignment: outgoing ? Alignment.centerRight : Alignment.centerLeft,
        child: Transform.rotate(
          angle: outgoing ? 0.012 : -0.012,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 330),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: background,
              border: Border.all(color: border, width: 4),
              boxShadow: const [
                BoxShadow(color: Colors.black, offset: Offset(7, 8)),
              ],
            ),
            child: Text(
              message.text.trim(),
              style: TextStyle(
                color: foreground,
                fontFamily: 'OptimaNova',
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenImageViewer extends StatelessWidget {
  final String imagePath;

  const _FullScreenImageViewer({required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.black,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarDividerColor: Colors.black,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).pop(),
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            boundaryMargin: const EdgeInsets.all(80),
            child: SizedBox.expand(
              child: _renderImage(imagePath, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _renderImage(String path, {required BoxFit fit}) {
  if (path.startsWith('assets/')) {
    return Image.asset(path, fit: fit);
  }
  return Image.file(
    File(path),
    fit: fit,
    errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
  );
}

// ── Sender badge ─────────────────────────────────────────────────────────────
// Small square in P5 style: thick black border, white fill, portrait face.

class _SenderBadge extends StatelessWidget {
  final Message message;
  const _SenderBadge({required this.message});

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
            child: ClipPath(clipper: const _BadgeClipper(), child: _portrait()),
          ),
        ],
      ),
    );
  }

  Widget _portrait() {
    final avatar = message.avatarPath;
    if (avatar != null && avatar.isNotEmpty) {
      if (avatar.startsWith('assets/')) {
        return Image.asset(
          avatar,
          fit: BoxFit.cover,
          alignment: const Alignment(0, -0.6),
          errorBuilder: (_, _, _) => _fallbackPortrait(),
        );
      }
      return Image.file(
        File(avatar),
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.6),
        errorBuilder: (_, _, _) => _fallbackPortrait(),
      );
    }

    return _fallbackPortrait();
  }

  Widget _fallbackPortrait() {
    final portrait = message.sender.portraitAsset;
    final label = message.avatarLabel?.trim();
    if (label != null && label.isNotEmpty) {
      final visibleText = label.substring(0, label.length.clamp(1, 2));
      return ColoredBox(
        color: Colors.white,
        child: Center(
          child: Text(
            visibleText.toUpperCase(),
            style: const TextStyle(
              color: Colors.black,
              fontFamily: 'OptimaNova',
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      );
    }
    if (portrait == null) return const SizedBox.shrink();

    return Image.asset(
      portrait,
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.6),
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
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
