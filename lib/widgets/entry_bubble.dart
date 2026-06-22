import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'persona_avatar.dart';

// Mirrors Entry.kt — received message with avatar on the left.
class EntryBubble extends StatelessWidget {
  final Message message;
  final double avatarBackgroundScale;
  final double avatarForegroundScale;
  final double messageHorizontalScale;
  final double messageVerticalScale;
  final double messageTextAlpha;

  const EntryBubble({
    super.key,
    required this.message,
    this.avatarBackgroundScale = 1.0,
    this.avatarForegroundScale = 1.0,
    this.messageHorizontalScale = 1.0,
    this.messageVerticalScale = 1.0,
    this.messageTextAlpha = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: _EntryLayoutBox(
        avatar: PersonaAvatar(
          sender: message.sender,
          backgroundScale: avatarBackgroundScale,
          foregroundScale: avatarForegroundScale,
        ),
        textBox: _EntryTextBox(
          text: message.text,
          messageHorizontalScale: messageHorizontalScale,
          messageVerticalScale: messageVerticalScale,
          messageTextAlpha: messageTextAlpha,
        ),
      ),
    );
  }
}

// ── Custom layout (mirrors EntryLayout in Compose) ─────────────────────────
// Uses a proper RenderBox so height is computed from actual text size.

class _EntryLayoutBox extends MultiChildRenderObjectWidget {
  _EntryLayoutBox({required Widget avatar, required Widget textBox})
    : super(children: [avatar, textBox]);

  @override
  RenderObject createRenderObject(BuildContext context) => _EntryRenderBox();

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _EntryRenderBox renderObject,
  ) {}
}

class _EntryParentData extends ContainerBoxParentData<RenderBox> {}

class _EntryRenderBox extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _EntryParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _EntryParentData> {
  static const _overlap = 18.0;
  static const _topPad = 4.0;
  static const _botPad = 6.0;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _EntryParentData) {
      child.parentData = _EntryParentData();
    }
  }

  @override
  void performLayout() {
    final avatar = firstChild!;
    final textBox = (avatar.parentData as _EntryParentData).nextSibling!;

    // Avatar: fixed size
    avatar.layout(
      const BoxConstraints.tightFor(width: kAvatarWidth, height: kAvatarHeight),
      parentUsesSize: true,
    );

    // Text box: up to (maxWidth - avatarWidth + overlap) wide, unconstrained height
    final textMaxWidth = constraints.maxWidth - kAvatarWidth + _overlap;
    textBox.layout(
      BoxConstraints(
        maxWidth: textMaxWidth,
        minWidth: 0,
        minHeight: 0,
        maxHeight: double.infinity,
      ),
      parentUsesSize: true,
    );

    final textWithPad = textBox.size.height + _topPad;
    final totalHeight = math.max(kAvatarHeight, textWithPad);

    (avatar.parentData as _EntryParentData).offset = Offset.zero;

    final textX = kAvatarWidth - _overlap;
    final textY = textWithPad > kAvatarHeight
        ? _topPad
        : totalHeight - textBox.size.height - _botPad;
    (textBox.parentData as _EntryParentData).offset = Offset(textX, textY);

    size = constraints.constrain(Size(constraints.maxWidth, totalHeight));
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }
}

// ── Text box with custom painted bubble ────────────────────────────────────

class _EntryTextBox extends StatelessWidget {
  final String text;
  final double messageHorizontalScale;
  final double messageVerticalScale;
  final double messageTextAlpha;

  const _EntryTextBox({
    required this.text,
    required this.messageHorizontalScale,
    required this.messageVerticalScale,
    required this.messageTextAlpha,
  });

  @override
  Widget build(BuildContext context) {
    final isLong = text.length > 280;
    return CustomPaint(
      painter: _EntryBubblePainter(
        hScale: messageHorizontalScale,
        vScale: messageVerticalScale,
      ),
      child: Opacity(
        opacity: messageTextAlpha.clamp(0.0, 1.0),
        child: Padding(
          padding: EdgeInsets.only(
            left: isLong ? 38 : 42,
            top: isLong ? 16 : 20,
            right: isLong ? 28 : 32,
            bottom: isLong ? 16 : 20,
          ),
          child: Text(
            text,
            style: TextStyle(
              color: Colors.white,
              fontSize: isLong ? 12.5 : 14,
              height: isLong ? 1.18 : null,
              fontFamily: 'OptimaNova',
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _EntryBubblePainter extends CustomPainter {
  final double hScale;
  final double vScale;

  const _EntryBubblePainter({required this.hScale, required this.vScale});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Stem Y anchor (mirrors getStemY logic from Entry.kt)
    final stemY = (h + 4) > kAvatarHeight ? kAvatarHeight - 16 : h - 5;

    // Pivot for scaling: left edge of stem, at stemY
    const pivotX = 0.0;
    final pivotY = stemY;

    // --- Outer white stem (not scaled) ---
    canvas.drawPath(_outerStem(stemY), Paint()..color = Colors.white);

    // --- Scaled outer white box ---
    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.scale(hScale, vScale);
    canvas.translate(-pivotX, -pivotY);
    canvas.drawPath(_outerBox(w, h), Paint()..color = Colors.white);
    canvas.restore();

    // --- Inner black stem (not scaled) ---
    canvas.drawPath(_innerStem(stemY), Paint()..color = Colors.black);

    // --- Scaled inner black box ---
    canvas.save();
    canvas.translate(pivotX, pivotY);
    canvas.scale(hScale, vScale);
    canvas.translate(-pivotX, -pivotY);
    canvas.drawPath(_innerBox(w, h), Paint()..color = Colors.black);
    canvas.restore();
  }

  Path _outerStem(double sy) => Path()
    ..moveTo(0, sy - 19.2)
    ..lineTo(19.5, sy - 37.2)
    ..lineTo(20.8, sy - 31.5)
    ..lineTo(32.4, sy - 39.3)
    ..lineTo(30.6, sy - 15.8)
    ..lineTo(11.7, sy - 12.6)
    ..lineTo(10, sy - 20)
    ..close();

  Path _innerStem(double sy) => Path()
    ..moveTo(4.6, sy - 22.2)
    ..lineTo(17, sy - 33.2)
    ..lineTo(19.3, sy - 28.1)
    ..lineTo(34.4, sy - 36.5)
    ..lineTo(34, sy - 21.4)
    ..lineTo(14.4, sy - 18.6)
    ..lineTo(12.8, sy - 25.4)
    ..close();

  Path _outerBox(double w, double h) => Path()
    ..moveTo(31.7, 3.1)
    ..lineTo(w, 0)
    ..lineTo(w - 23, h)
    ..lineTo(15.6, h - 8)
    ..close();

  Path _innerBox(double w, double h) => Path()
    ..moveTo(33, 7.7)
    ..lineTo(w - 13, 3.7)
    ..lineTo(w - 25.7, h - 4.6)
    ..lineTo(20.4, h - 12)
    ..close();

  @override
  bool shouldRepaint(_EntryBubblePainter old) =>
      old.hScale != hScale || old.vScale != vScale;
}
