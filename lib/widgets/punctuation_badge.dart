import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum _PunctuationKind { question, exclamation }

class PunctuationBadge extends StatelessWidget {
  final String text;

  const PunctuationBadge({super.key, required this.text});

  _PunctuationKind? get _kind {
    final value = text.trimRight();
    if (value.endsWith('?')) return _PunctuationKind.question;
    if (value.endsWith('!')) return _PunctuationKind.exclamation;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final kind = _kind;
    if (kind == null) return const SizedBox.shrink();

    final asset = switch (kind) {
      _PunctuationKind.question => 'assets/icons/question_mark.svg',
      _PunctuationKind.exclamation => 'assets/icons/exclamation_mark.svg',
    };

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.38, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Transform.translate(
        offset: Offset(kind == _PunctuationKind.exclamation ? -5 : 0, 0),
        child: Transform.rotate(
          angle: kind == _PunctuationKind.question ? 0.08 : -0.08,
          child: SvgPicture.asset(asset, width: 25, height: 34),
        ),
      ),
    );
  }
}
