import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/message.dart';

class FileBubble extends StatelessWidget {
  final Message message;
  final double hScale;
  final double vScale;
  final double alpha;

  const FileBubble({
    super.key,
    required this.message,
    this.hScale = 1,
    this.vScale = 1,
    this.alpha = 1,
  });

  String get _sizeLabel {
    final bytes = message.fileSize ?? 0;
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get _extension {
    final name = message.fileName ?? '';
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return 'FILE';
    return name
        .substring(dot + 1)
        .toUpperCase()
        .substring(0, math.min(4, name.length - dot - 1));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(70, 4, 18, 4),
      child: Transform(
        transform: Matrix4.diagonal3Values(hScale, vScale, 1),
        alignment: Alignment.centerRight,
        child: Opacity(
          opacity: alpha.clamp(0, 1),
          child: Transform.rotate(
            angle: -0.025,
            child: CustomPaint(
              painter: const _FilePanelPainter(),
              child: SizedBox(
                height: 86,
                child: Row(
                  children: [
                    const SizedBox(width: 18),
                    CustomPaint(
                      painter: const _FileIconPainter(),
                      child: SizedBox(
                        width: 54,
                        height: 58,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 9),
                            child: Text(
                              _extension,
                              style: const TextStyle(
                                color: Colors.black,
                                fontFamily: 'OptimaNova',
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.fileName ?? 'File',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'OptimaNova',
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              height: 1.05,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _sizeLabel,
                            style: const TextStyle(
                              color: Colors.white60,
                              fontFamily: 'OptimaNova',
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.download_done,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilePanelPainter extends CustomPainter {
  const _FilePanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..moveTo(8, 8)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 13, size.height - 5)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(outer, Paint()..color = Colors.white);

    final inner = Path()
      ..moveTo(12, 12)
      ..lineTo(size.width - 6, 6)
      ..lineTo(size.width - 17, size.height - 10)
      ..lineTo(6, size.height - 5)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_FilePanelPainter oldDelegate) => false;
}

class _FileIconPainter extends CustomPainter {
  const _FileIconPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, 0)
      ..lineTo(size.width - 12, 3)
      ..lineTo(size.width, 15)
      ..lineTo(size.width - 5, size.height)
      ..lineTo(0, size.height - 4)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.white);

    final fold = Path()
      ..moveTo(size.width - 13, 3)
      ..lineTo(size.width - 13, 16)
      ..lineTo(size.width, 15)
      ..close();
    canvas.drawPath(fold, Paint()..color = const Color(0xFFF70000));
  }

  @override
  bool shouldRepaint(_FileIconPainter oldDelegate) => false;
}
