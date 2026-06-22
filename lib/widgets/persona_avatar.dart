import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';

class PersonaAvatar extends StatelessWidget {
  final Sender sender;
  final double backgroundScale;
  final double foregroundScale;

  const PersonaAvatar({
    super.key,
    required this.sender,
    this.backgroundScale = 1.0,
    this.foregroundScale = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: kAvatarWidth,
      height: kAvatarHeight,
      child: Transform.scale(
        scale: backgroundScale,
        child: CustomPaint(
          painter: _AvatarBackgroundPainter(senderColor: sender.color),
          child: ClipPath(
            clipper: _AvatarClipClipper(),
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Transform.scale(
                  scale: foregroundScale,
                  alignment: Alignment.bottomCenter,
                  child: SizedBox(
                    width: 80,
                    height: 80,
                    child: _buildPortrait(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPortrait() {
    final asset = sender.portraitAsset;
    if (asset == null) return _AvatarPlaceholder(sender: sender);
    return Image.asset(
      asset,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _AvatarPlaceholder(sender: sender),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final Sender sender;

  const _AvatarPlaceholder({required this.sender});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        sender.name.substring(0, 1).toUpperCase(),
        style: const TextStyle(
          color: Colors.black,
          fontFamily: 'OptimaNova',
          fontSize: 36,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AvatarBackgroundPainter extends CustomPainter {
  final Color senderColor;
  const _AvatarBackgroundPainter({required this.senderColor});

  @override
  void paint(Canvas canvas, Size size) {
    // Black box (outermost)
    canvas.drawPath(_blackBox(), Paint()..color = Colors.black);
    // White box
    canvas.drawPath(_whiteBox(), Paint()..color = Colors.white);
    // Colored box
    canvas.drawPath(_coloredBox(), Paint()..color = senderColor);
  }

  Path _blackBox() => Path()
    ..moveTo(0, 17)
    ..lineTo(100.5, 27.2)
    ..lineTo(110, 72.7)
    ..lineTo(33.4, 90)
    ..close();

  Path _whiteBox() => Path()
    ..moveTo(16.4, 20.5)
    ..lineTo(96.7, 30.4)
    ..lineTo(106.4, 70)
    ..lineTo(37.8, 80.4)
    ..close();

  Path _coloredBox() => Path()
    ..moveTo(22.5, 28)
    ..lineTo(94.4, 31.4)
    ..lineTo(104.3, 67.5)
    ..lineTo(40, 76.6)
    ..close();

  @override
  bool shouldRepaint(_AvatarBackgroundPainter old) =>
      old.senderColor != senderColor;
}

class _AvatarClipClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(10.3, -5.6)
    ..lineTo(114.7, -5.6)
    ..lineTo(114.7, 65.6)
    ..lineTo(40, 76.6)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
