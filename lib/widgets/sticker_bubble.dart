import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lottie/lottie.dart';
import 'package:video_player/video_player.dart';
import '../models/message.dart';
import '../theme/persona_colors.dart';
import 'persona_avatar.dart';

// Sticker message — avatar on the left, bare transparent sticker on the right.
// Supported formats:
//   .webp  — static sticker (Flutter native)
//   .tgs   — animated Lottie sticker (gzip-compressed JSON from Telegram)
class StickerBubble extends StatelessWidget {
  final Message message;
  final double avatarBackgroundScale;
  final double avatarForegroundScale;
  final double scale;
  final double alpha;

  static const _kSize = 160.0;
  static const _kOverlap = 18.0;
  static const _kExtraLeft = 40.0;

  const StickerBubble({
    super.key,
    required this.message,
    this.avatarBackgroundScale = 1.0,
    this.avatarForegroundScale = 1.0,
    this.scale = 1.0,
    this.alpha = 1.0,
  });

  String get _path => message.animatedMediaPath!;
  bool get _isLottie => _path.endsWith('.tgs');
  bool get _isVideo => _path.endsWith('.webm');

  @override
  Widget build(BuildContext context) {
    const totalHeight = _kSize > kAvatarHeight ? _kSize : kAvatarHeight + 0.0;

    if (message.sender == Sender.ren) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: SizedBox(
          height: totalHeight,
          child: Align(
            alignment: Alignment.centerRight,
            child: Transform.scale(
              scale: scale,
              alignment: Alignment.centerRight,
              child: Opacity(
                opacity: alpha.clamp(0.0, 1.0),
                child: SizedBox(width: _kSize, height: _kSize, child: _media()),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        height: totalHeight,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              top: 0,
              child: PersonaAvatar(
                sender: message.sender,
                backgroundScale: avatarBackgroundScale,
                foregroundScale: avatarForegroundScale,
              ),
            ),
            Positioned(
              left: kAvatarWidth - _kOverlap + _kExtraLeft,
              top: (totalHeight - _kSize) / 2,
              child: Transform.scale(
                scale: scale,
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: alpha.clamp(0.0, 1.0),
                  child: SizedBox(
                    width: _kSize,
                    height: _kSize,
                    child: _media(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _media() {
    if (_isLottie) return _TgsSticker(path: _path, size: _kSize);
    if (_isVideo) return _WebmSticker(path: _path, size: _kSize);
    return Image.asset(
      _path,
      width: _kSize,
      height: _kSize,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => const SizedBox.shrink(),
    );
  }
}

// ── Animated Lottie sticker (.tgs = gzip-compressed Lottie JSON) ─────────────

class _TgsSticker extends StatefulWidget {
  final String path;
  final double size;
  const _TgsSticker({required this.path, required this.size});

  @override
  State<_TgsSticker> createState() => _TgsStickerState();
}

class _TgsStickerState extends State<_TgsSticker> {
  Uint8List? _bytes;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await rootBundle.load(widget.path);
      // .tgs is gzip-compressed — decompress before feeding to Lottie
      final compressed = data.buffer.asUint8List();
      final decompressed = GZipCodec().decode(compressed);
      if (mounted) setState(() => _bytes = Uint8List.fromList(decompressed));
    } catch (e) {
      debugPrint('TgsSticker load error: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error || _bytes == null) return const SizedBox.shrink();
    return Lottie.memory(
      _bytes!,
      width: widget.size,
      height: widget.size,
      fit: BoxFit.contain,
      repeat: true,
      errorBuilder: (_, e, __) {
        debugPrint('Lottie render error: $e');
        return const SizedBox.shrink();
      },
    );
  }
}

// ── Video sticker (.webm, no alpha) ──────────────────────────────────────────

class _WebmSticker extends StatefulWidget {
  final String path;
  final double size;
  const _WebmSticker({required this.path, required this.size});

  @override
  State<_WebmSticker> createState() => _WebmStickerState();
}

class _WebmStickerState extends State<_WebmSticker> {
  VideoPlayerController? _ctrl;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // VideoPlayerController.asset() is unreliable for webm on Android.
      // Copy the asset to a temp file and use VideoPlayerController.file().
      final data = await rootBundle.load(widget.path);
      final bytes = data.buffer.asUint8List();
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/${widget.path.hashCode}.webm');
      await file.writeAsBytes(bytes, flush: true);

      final ctrl = VideoPlayerController.file(file);
      await ctrl.setLooping(true);
      await ctrl.initialize();
      if (!mounted) {
        ctrl.dispose();
        return;
      }
      setState(() {
        _ctrl = ctrl;
        _ready = true;
      });
      ctrl.play();
    } catch (e) {
      debugPrint('WebmSticker init error: $e');
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl;
    if (!_ready || ctrl == null) return const SizedBox.shrink();
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: ctrl.value.size.width,
          height: ctrl.value.size.height,
          child: VideoPlayer(ctrl),
        ),
      ),
    );
  }
}
