import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/chat_summary.dart';

/// One row in the chat list — a P5 IM "thread card".
///
/// Layout (left → right):
///   [ avatar stack ]  [ white-bordered black banner  →  date-tag + title ]
///
/// The banner is a parallelogram leaning clockwise (top-right is the highest
/// point, bottom-left the lowest) — the same geometry as [EntryBubble] so the
/// visual language is consistent with the message bubbles inside a chat.
class ChatListItem extends StatelessWidget {
  final ChatSummary chat;
  final double rotation;
  final bool isSelected;
  final bool showHoldBadge;
  final VoidCallback onTap;

  const ChatListItem({
    super.key,
    required this.chat,
    required this.rotation,
    required this.isSelected,
    this.showHoldBadge = true,
    required this.onTap,
  });

  static const _rowHeight = 96.0;
  static const _badgeSize = 66.0;
  static const _badgeOverlap = 18.0;

  @override
  Widget build(BuildContext context) {
    const badgeStripW = _badgeSize;
    const textLeft = badgeStripW + 12;

    return Transform.rotate(
      angle: rotation,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: _rowHeight,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Banner — starts inside the avatar column so the last badge
              // overlaps the banner's left edge.
              Positioned(
                left: badgeStripW - _badgeOverlap,
                right: 6,
                top: 14,
                bottom: 10,
                child: CustomPaint(
                  painter: _BannerPainter(isSelected: isSelected),
                ),
              ),

              // Date stamp — three joined boxes straddling the banner's top edge.
              Positioned(
                left: textLeft,
                top: 3,
                child: _DateStamp(date: chat.updatedAt),
              ),

              // Title — inside the banner, below the date stamp.
              Positioned(
                left: textLeft,
                right: 24,
                top: 46,
                child: Text(
                  chat.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontFamily: 'OptimaNova',
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ),

              // Telegram exposes one avatar per chat. Group participant
              // portraits are composed inside this single P5 frame only when
              // the group itself has no photo.
              Positioned(
                left: 4,
                top: 10,
                child: _ChatAvatarBadge(chat: chat, size: _badgeSize),
              ),
              if (chat.isNew)
                Positioned(
                  left: -8,
                  top: -4,
                  child: SvgPicture.asset(
                    'assets/icons/new_sign.svg',
                    width: 76,
                    height: 46,
                    fit: BoxFit.fill,
                  ),
                )
              else if (showHoldBadge && chat.shouldShowHoldBadge)
                Positioned(
                  left: -8,
                  top: -4,
                  child: SvgPicture.asset(
                    'assets/icons/hold_badge.svg',
                    width: 76,
                    height: 46,
                    fit: BoxFit.fill,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Banner background ───────────────────────────────────────────────────────
// Single solid-black parallelogram — no white frame, no shadow.
// Same clockwise-leaning geometry as [EntryBubble] so every black element on
// screen reads as part of the same visual language.

class _BannerPainter extends CustomPainter {
  final bool isSelected;

  const _BannerPainter({required this.isSelected});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final outer = _shape(w, h);
    canvas.drawPath(outer, Paint()..color = Colors.black);

    if (isSelected) {
      canvas.drawPath(
        _selectedShape(w, h),
        Paint()..color = const Color(0xFFF70000),
      );
    }
  }

  // Clockwise-leaning parallelogram: TR highest, BL lowest.
  Path _shape(double w, double h) => Path()
    ..moveTo(22, 4)
    ..lineTo(w, 0)
    ..lineTo(w - 16, h)
    ..lineTo(10, h - 6)
    ..close();

  Path _selectedShape(double w, double h) => Path()
    ..moveTo(25, 10)
    ..lineTo(w - 9, 6)
    ..lineTo(w - 21, h - 8)
    ..lineTo(17, h - 12)
    ..close();

  @override
  bool shouldRepaint(_BannerPainter old) => old.isSelected != isSelected;
}

// ── Date stamp ──────────────────────────────────────────────────────────────
// Persona-5-style date chip: a white, black-bordered rectangle with a red
// diagonal parallelogram behind the slash — "4 / 18 Mo" — where:
//   • month + day numbers are red
//   • the "/" is white on the red stripe (the stripe *is* the slash accent)
//   • the weekday is black and leans right (italic skew)

const double _dsH = 30.0;
const double _dsW = 103.0;

class _DateStamp extends StatelessWidget {
  final DateTime date;
  const _DateStamp({required this.date});

  static const _days = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

  @override
  Widget build(BuildContext context) {
    final monthStr = date.month.toString();
    final dayStr = date.day.toString();
    final weekStr = _days[(date.weekday - 1) % 7];
    final dateAsset = switch (date.weekday) {
      DateTime.saturday => 'assets/icons/date_blue.svg',
      DateTime.sunday => 'assets/icons/date_red.svg',
      _ => 'assets/icons/date_stamp.svg',
    };
    final isWeekend =
        date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;

    return SizedBox(
      width: _dsW,
      height: _dsH,
      child: Stack(
        children: [
          // Background — white fill + red "/" stripe + black border.
          Positioned.fill(child: SvgPicture.asset(dateAsset, fit: BoxFit.fill)),

          // ── Month — small red number ──────────────────────────────────
          Positioned(
            left: 17,
            top: 6,
            width: 21,
            height: 20,
            child: Center(
              child: Text(
                monthStr,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 19,
                  fontFamily: 'OptimaNova',
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),

          // ── Day — bigger red number ───────────────────────────────────
          Positioned(
            left: 38,
            top: 4,
            width: 25,
            height: 21,
            child: Center(
              child: Text(
                dayStr,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontFamily: 'OptimaNova',
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),

          // ── Weekday — black italic, leans right ───────────────────────
          Positioned(
            left: isWeekend ? 61 : 59,
            top: 4,
            width: 22,
            height: 18,
            child: Center(
              child: Text(
                weekStr,
                style: TextStyle(
                  color: isWeekend ? Colors.white : Colors.black,
                  fontSize: 12,
                  fontFamily: 'OptimaNova',
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar badge — small skewed black-bordered square with portrait ─────────

class _ChatAvatarBadge extends StatelessWidget {
  final ChatSummary chat;
  final double size;

  const _ChatAvatarBadge({required this.chat, required this.size});

  @override
  Widget build(BuildContext context) {
    final isGroup = chat.type == ChatType.group;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _BadgeBgPainter(color: Colors.white)),
          ),
          Positioned.fill(
            child: ClipPath(
              clipper: const _BadgeClipper(),
              child: isGroup
                  ? Center(
                      child: Transform.rotate(
                        angle: -0.04,
                        child: Text(
                          _label(),
                          maxLines: 1,
                          style: const TextStyle(
                            color: Colors.black,
                            fontFamily: 'OptimaNova',
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                        ),
                      ),
                    )
                  : _directChatArtwork(),
            ),
          ),
          if (chat.isActive)
            Positioned(
              right: 0,
              bottom: 0,
              child: _ActivityBadge(activity: chat.activity),
            ),
        ],
      ),
    );
  }

  Widget _directChatArtwork() {
    final path =
        chat.avatarPath ??
        (chat.participants.isEmpty
            ? null
            : chat.participants.first.portraitAsset);
    if (path == null) return _fallbackArtwork();

    if (path.startsWith('assets/')) {
      return Image.asset(
        path,
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.5),
        errorBuilder: (_, _, _) => _fallbackArtwork(),
      );
    }

    return Image.file(
      File(path),
      fit: BoxFit.cover,
      alignment: const Alignment(0, -0.5),
      errorBuilder: (_, _, _) => _fallbackArtwork(),
    );
  }

  Widget _fallbackArtwork() {
    return ColoredBox(
      color: Colors.white,
      child: Center(
        child: Text(
          _label(),
          style: const TextStyle(
            color: Colors.black,
            fontFamily: 'OptimaNova',
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  String _label() {
    final explicit = chat.avatarLabel?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit.substring(0, explicit.length.clamp(1, 2)).toUpperCase();
    }

    final words = chat.title
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '?';
    if (words.length == 1) {
      return words.first.substring(0, 1).toUpperCase();
    }
    return '${words.first[0]}${words[1][0]}'.toUpperCase();
  }
}

class _ActivityBadge extends StatelessWidget {
  final ChatActivity activity;

  const _ActivityBadge({required this.activity});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CustomPaint(painter: _ActivityBadgePainter(activity: activity)),
    );
  }
}

class _ActivityBadgePainter extends CustomPainter {
  final ChatActivity activity;

  const _ActivityBadgePainter({required this.activity});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawPath(_octagon(center, 9), Paint()..color = Colors.black);
    canvas.drawPath(_octagon(center, 6.7), Paint()..color = Colors.white);
    canvas.drawPath(
      _octagon(center, 4.7),
      Paint()..color = const Color(0xFFF70000),
    );
  }

  Path _octagon(Offset center, double radius) {
    final path = Path();
    for (int index = 0; index < 8; index++) {
      final angle = -math.pi / 8 + math.pi * 2 * index / 8;
      final point = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ActivityBadgePainter oldDelegate) => false;
}

class _BadgeBgPainter extends CustomPainter {
  final Color color;
  const _BadgeBgPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawPath(_outer(w, h), Paint()..color = Colors.black);
    canvas.drawPath(_white(w, h), Paint()..color = Colors.white);
    canvas.drawPath(_inner(w, h), Paint()..color = color);
  }

  Path _outer(double w, double h) => Path()
    ..moveTo(0, 4)
    ..lineTo(w - 5, 0)
    ..lineTo(w, h - 4)
    ..lineTo(4, h)
    ..close();

  Path _white(double w, double h) => Path()
    ..moveTo(4, 7)
    ..lineTo(w - 8, 3)
    ..lineTo(w - 4, h - 7)
    ..lineTo(8, h - 3)
    ..close();

  Path _inner(double w, double h) => Path()
    ..moveTo(7, 10)
    ..lineTo(w - 10, 6)
    ..lineTo(w - 6, h - 10)
    ..lineTo(10, h - 6)
    ..close();

  @override
  bool shouldRepaint(_BadgeBgPainter old) => old.color != color;
}

class _BadgeClipper extends CustomClipper<Path> {
  const _BadgeClipper();

  @override
  Path getClip(Size size) {
    final w = size.width;
    final h = size.height;
    return Path()
      ..moveTo(7, 10)
      ..lineTo(w - 10, 6)
      ..lineTo(w - 6, h - 10)
      ..lineTo(10, h - 6)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
