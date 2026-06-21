import 'package:flutter/material.dart';

enum ComposerPanelMode { none, attachments, emoji, gifs, stickers }

class ComposerPanel extends StatelessWidget {
  final ComposerPanelMode mode;
  final ValueChanged<ComposerPanelMode> onModeChanged;
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<String> onGifSelected;
  final ValueChanged<String> onStickerSelected;

  const ComposerPanel({
    super.key,
    required this.mode,
    required this.onModeChanged,
    required this.onPickPhoto,
    required this.onPickFile,
    required this.onEmojiSelected,
    required this.onGifSelected,
    required this.onStickerSelected,
  });

  static const _emojis = [
    '😀',
    '😂',
    '🥹',
    '😍',
    '😎',
    '🤔',
    '😴',
    '😭',
    '😡',
    '👍',
    '👎',
    '❤️',
    '🔥',
    '🎉',
    '💀',
    '✨',
    '🙏',
    '👀',
    '🤝',
    '💯',
    '😈',
    '🤡',
    '🫡',
    '🤨',
  ];

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: const _PanelPainter(),
      child: SizedBox(
        height: 244,
        child: Column(
          children: [
            _ModeBar(mode: mode, onModeChanged: onModeChanged),
            Expanded(child: _content()),
          ],
        ),
      ),
    );
  }

  Widget _content() => switch (mode) {
    ComposerPanelMode.attachments => _AttachmentActions(
      onPickPhoto: onPickPhoto,
      onPickFile: onPickFile,
      onOpenGifs: () => onModeChanged(ComposerPanelMode.gifs),
      onOpenStickers: () => onModeChanged(ComposerPanelMode.stickers),
    ),
    ComposerPanelMode.emoji => _EmojiGrid(
      emojis: _emojis,
      onSelected: onEmojiSelected,
    ),
    ComposerPanelMode.gifs => _GifGrid(onSelected: onGifSelected),
    ComposerPanelMode.stickers => _StickerGrid(onSelected: onStickerSelected),
    ComposerPanelMode.none => const SizedBox.shrink(),
  };
}

class _ModeBar extends StatelessWidget {
  final ComposerPanelMode mode;
  final ValueChanged<ComposerPanelMode> onModeChanged;

  const _ModeBar({required this.mode, required this.onModeChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          const SizedBox(width: 12),
          _ModeButton(
            icon: Icons.add,
            tooltip: 'Attachments',
            selected: mode == ComposerPanelMode.attachments,
            onTap: () => onModeChanged(ComposerPanelMode.attachments),
          ),
          _ModeButton(
            icon: Icons.emoji_emotions,
            tooltip: 'Emoji',
            selected: mode == ComposerPanelMode.emoji,
            onTap: () => onModeChanged(ComposerPanelMode.emoji),
          ),
          _ModeButton(
            label: 'GIF',
            tooltip: 'GIF',
            selected: mode == ComposerPanelMode.gifs,
            onTap: () => onModeChanged(ComposerPanelMode.gifs),
          ),
          _ModeButton(
            icon: Icons.sticky_note_2,
            tooltip: 'Stickers',
            selected: mode == ComposerPanelMode.stickers,
            onTap: () => onModeChanged(ComposerPanelMode.stickers),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final IconData? icon;
  final String? label;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    this.icon,
    this.label,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: CustomPaint(
          painter: _ModeButtonPainter(selected: selected),
          child: SizedBox(
            width: 54,
            height: 38,
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 22,
                      color: selected ? Colors.white : Colors.black,
                    )
                  : Text(
                      label!,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black,
                        fontFamily: 'OptimaNova',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentActions extends StatelessWidget {
  final VoidCallback onPickPhoto;
  final VoidCallback onPickFile;
  final VoidCallback onOpenGifs;
  final VoidCallback onOpenStickers;

  const _AttachmentActions({
    required this.onPickPhoto,
    required this.onPickFile,
    required this.onOpenGifs,
    required this.onOpenStickers,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
      crossAxisCount: 2,
      childAspectRatio: 2.35,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _ActionTile(icon: Icons.photo, label: 'PHOTO', onTap: onPickPhoto),
        _ActionTile(
          icon: Icons.insert_drive_file,
          label: 'FILE',
          onTap: onPickFile,
        ),
        _ActionTile(icon: Icons.gif_box, label: 'GIF', onTap: onOpenGifs),
        _ActionTile(
          icon: Icons.sticky_note_2,
          label: 'STICKER',
          onTap: onOpenStickers,
        ),
      ],
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _ActionTilePainter(),
        child: Row(
          children: [
            const SizedBox(width: 15),
            Icon(icon, color: Colors.white, size: 27),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                style: const TextStyle(
                  color: Colors.white,
                  fontFamily: 'OptimaNova',
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmojiGrid extends StatelessWidget {
  final List<String> emojis;
  final ValueChanged<String> onSelected;

  const _EmojiGrid({required this.emojis, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
      ),
      itemCount: emojis.length,
      itemBuilder: (context, index) => InkWell(
        onTap: () => onSelected(emojis[index]),
        child: Center(
          child: Text(emojis[index], style: const TextStyle(fontSize: 27)),
        ),
      ),
    );
  }
}

class _GifGrid extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _GifGrid({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      crossAxisCount: 2,
      childAspectRatio: 1.55,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _MediaTile(
          path: 'assets/stickers/persona4.gif',
          label: 'PERSONA 4',
          onTap: () => onSelected('assets/stickers/persona4.gif'),
        ),
      ],
    );
  }
}

class _StickerGrid extends StatelessWidget {
  final ValueChanged<String> onSelected;

  const _StickerGrid({required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _MediaTile(
          path: 'assets/stickers/sticker.webp',
          label: 'STICKER',
          onTap: () => onSelected('assets/stickers/sticker.webp'),
        ),
        _VideoStickerTile(
          onTap: () => onSelected('assets/stickers/sticker.webm'),
        ),
      ],
    );
  }
}

class _MediaTile extends StatelessWidget {
  final String path;
  final String label;
  final VoidCallback onTap;

  const _MediaTile({
    required this.path,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _MediaTilePainter(),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Padding(
              padding: const EdgeInsets.all(8),
              child: Image.asset(path, fit: BoxFit.contain),
            ),
            Positioned(
              left: 5,
              bottom: 4,
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'OptimaNova',
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoStickerTile extends StatelessWidget {
  final VoidCallback onTap;

  const _VideoStickerTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CustomPaint(
        painter: const _MediaTilePainter(),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_fill, color: Colors.black, size: 42),
            SizedBox(height: 5),
            Text(
              'VIDEO',
              style: TextStyle(
                color: Colors.black,
                fontFamily: 'OptimaNova',
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PanelPainter extends CustomPainter {
  const _PanelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..moveTo(8, 12)
      ..lineTo(size.width - 5, 0)
      ..lineTo(size.width, size.height - 9)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(outer, Paint()..color = Colors.black);

    final inner = Path()
      ..moveTo(12, 16)
      ..lineTo(size.width - 9, 6)
      ..lineTo(size.width - 5, size.height - 13)
      ..lineTo(5, size.height - 5)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_PanelPainter oldDelegate) => false;
}

class _ModeButtonPainter extends CustomPainter {
  final bool selected;

  const _ModeButtonPainter({required this.selected});

  @override
  void paint(Canvas canvas, Size size) {
    if (!selected) return;
    final path = Path()
      ..moveTo(4, 5)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 5, size.height - 3)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_ModeButtonPainter oldDelegate) =>
      oldDelegate.selected != selected;
}

class _ActionTilePainter extends CustomPainter {
  const _ActionTilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(4, 7)
      ..lineTo(size.width, 0)
      ..lineTo(size.width - 8, size.height - 4)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_ActionTilePainter oldDelegate) => false;
}

class _MediaTilePainter extends CustomPainter {
  const _MediaTilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Path()
      ..moveTo(5, 5)
      ..lineTo(size.width - 4, 0)
      ..lineTo(size.width, size.height - 6)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(outer, Paint()..color = Colors.black);

    final inner = Path()
      ..moveTo(9, 9)
      ..lineTo(size.width - 8, 5)
      ..lineTo(size.width - 5, size.height - 10)
      ..lineTo(5, size.height - 5)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_MediaTilePainter oldDelegate) => false;
}
