import 'package:flutter/material.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'persona_avatar.dart';

// Dimensions for mini portraits in the header
const _pW = 44.0;
const _pH = 40.0;
const _overlap = 12.0; // how much consecutive portraits overlap

class ChatHeader extends StatelessWidget {
  final String chatName;

  /// Participants shown as mini avatars (Ren excluded — he's the user).
  final List<Sender> participants;

  const ChatHeader({
    super.key,
    required this.chatName,
    required this.participants,
  });

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;

    // Total width taken by the overlapping portrait strip
    final stripW = participants.isEmpty
        ? 0.0
        : _pW + (_pW - _overlap) * (participants.length - 1);

    return Padding(
      padding: EdgeInsets.fromLTRB(10, topPad + 6, 10, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Mini avatar strip ────────────────────────────────────────────
          SizedBox(
            width: stripW,
            height: _pH,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                for (int i = 0; i < participants.length; i++)
                  Positioned(
                    left: i * (_pW - _overlap),
                    top: 0,
                    child: _MiniAvatar(sender: participants[i]),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          // ── Chat name box ────────────────────────────────────────────────
          Expanded(
            child: CustomPaint(
              painter: const _NameBoxPainter(),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 9, 10, 9),
                child: Text(
                  chatName,
                  style: const TextStyle(
                    fontFamily: 'OptimaNova',
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: Colors.black,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Mini avatar ─────────────────────────────────────────────────────────────
//
// Reuses PersonaAvatar (110×90 dp) scaled down to _pW×_pH via FittedBox.

class _MiniAvatar extends StatelessWidget {
  final Sender sender;
  const _MiniAvatar({required this.sender});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _pW,
      height: _pH,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: kAvatarWidth,
          height: kAvatarHeight,
          child: PersonaAvatar(sender: sender),
        ),
      ),
    );
  }
}

// ── Name box painter ────────────────────────────────────────────────────────
//
// Classic Persona 5 parallelogram: /──────/ — black outer, white inner.

class _NameBoxPainter extends CustomPainter {
  const _NameBoxPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    const skew = 7.0;

    canvas.drawPath(
      Path()
        ..moveTo(skew, 0)
        ..lineTo(w, 0)
        ..lineTo(w - skew, h)
        ..lineTo(0, h)
        ..close(),
      Paint()..color = Colors.black,
    );

    const b = 3.0;
    canvas.drawPath(
      Path()
        ..moveTo(skew + b, b)
        ..lineTo(w - b, b)
        ..lineTo(w - skew - b, h - b)
        ..lineTo(b, h - b)
        ..close(),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_NameBoxPainter old) => false;
}
