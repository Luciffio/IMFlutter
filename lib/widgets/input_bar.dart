import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';

import 'composer_panel.dart';
import 'typing_indicator.dart';

typedef SendFileCallback = void Function(String path, String name, int size);

class InputBar extends StatefulWidget {
  final ValueChanged<String>? onSend;
  final ValueChanged<String>? onSendImage;
  final SendFileCallback? onSendFile;
  final ValueChanged<String>? onSendSticker;
  final ValueChanged<String>? onSendGif;
  final bool showTypingIndicator;

  const InputBar({
    super.key,
    this.onSend,
    this.onSendImage,
    this.onSendFile,
    this.onSendSticker,
    this.onSendGif,
    this.showTypingIndicator = false,
  });

  @override
  State<InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<InputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _imagePicker = ImagePicker();
  ComposerPanelMode _panelMode = ComposerPanelMode.none;

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onSend?.call(text);
    _controller.clear();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 90,
      );
      if (file == null) return;
      widget.onSendImage?.call(file.path);
      _closePanel();
    } catch (error) {
      debugPrint('Image picker error: $error');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      final file = result?.files.single;
      final path = file?.path;
      if (file == null || path == null) return;
      widget.onSendFile?.call(path, file.name, file.size);
      _closePanel();
    } catch (error) {
      debugPrint('File picker error: $error');
    }
  }

  void _togglePanel(ComposerPanelMode mode) {
    _focusNode.unfocus();
    setState(() {
      _panelMode = _panelMode == mode ? ComposerPanelMode.none : mode;
    });
  }

  void _closePanel() {
    if (!mounted || _panelMode == ComposerPanelMode.none) return;
    setState(() => _panelMode = ComposerPanelMode.none);
  }

  void _insertEmoji(String emoji) {
    final selection = _controller.selection;
    final start = selection.isValid ? selection.start : _controller.text.length;
    final end = selection.isValid ? selection.end : _controller.text.length;
    final text = _controller.text.replaceRange(start, end, emoji);
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(8, 0, 8, 10 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 120),
              child: widget.showTypingIndicator
                  ? const Padding(
                      key: ValueKey('typing_indicator'),
                      padding: EdgeInsets.only(left: 2, bottom: 7),
                      child: TypingIndicator(),
                    )
                  : const SizedBox.shrink(key: ValueKey('no_typing')),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            transitionBuilder: (child, animation) => SizeTransition(
              sizeFactor: animation,
              axisAlignment: 1,
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: _panelMode == ComposerPanelMode.none
                ? const SizedBox.shrink(key: ValueKey('closed'))
                : Padding(
                    key: ValueKey(_panelMode),
                    padding: const EdgeInsets.only(bottom: 7),
                    child: ComposerPanel(
                      mode: _panelMode,
                      onModeChanged: _togglePanel,
                      onPickPhoto: _pickImage,
                      onPickFile: _pickFile,
                      onEmojiSelected: _insertEmoji,
                      onGifSelected: (path) {
                        widget.onSendGif?.call(path);
                        _closePanel();
                      },
                      onStickerSelected: (path) {
                        widget.onSendSticker?.call(path);
                        _closePanel();
                      },
                    ),
                  ),
          ),
          CustomPaint(
            painter: const _BarPainter(),
            child: AnimatedSize(
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
                      child: Tooltip(
                        message: 'Attachments',
                        child: GestureDetector(
                          onTap: () =>
                              _togglePanel(ComposerPanelMode.attachments),
                          child: Transform.rotate(
                            angle: _panelMode == ComposerPanelMode.attachments
                                ? 0
                                : -0.22,
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CustomPaint(
                                painter: _PlusPainter(
                                  isClose:
                                      _panelMode ==
                                      ComposerPanelMode.attachments,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          onTap: _closePanel,
                          minLines: 1,
                          maxLines: 3,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          scrollPhysics: const ClampingScrollPhysics(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 14,
                            fontFamily: 'OptimaNova',
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            hintText: 'Message...',
                            hintStyle: TextStyle(
                              color: Colors.black38,
                              fontSize: 14,
                              fontFamily: 'OptimaNova',
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 11, 0, 11),
                      child: Tooltip(
                        message: 'Emoji',
                        child: GestureDetector(
                          onTap: () => _togglePanel(ComposerPanelMode.emoji),
                          child: SvgPicture.asset(
                            'assets/icons/smile.svg',
                            width: 32,
                            height: 32,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 14, 12),
                      child: GestureDetector(
                        onTap: _send,
                        child: const SizedBox(
                          width: 30,
                          height: 30,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CustomPaint(painter: _TrianglePainter()),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  const _BarPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    const skew = 8.0;
    final inset = height * 0.05;

    final outer = Path()
      ..moveTo(0, 0)
      ..lineTo(width, inset)
      ..lineTo(width, height - inset)
      ..lineTo(skew, height)
      ..close();
    canvas.drawPath(outer, Paint()..color = Colors.black);

    const border = 3.0;
    final inner = Path()
      ..moveTo(border, border)
      ..lineTo(width - border, inset + border)
      ..lineTo(width - border, height - inset - border)
      ..lineTo(skew + border, height - border)
      ..close();
    canvas.drawPath(inner, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_BarPainter oldDelegate) => false;
}

class _PlusPainter extends CustomPainter {
  final bool isClose;

  const _PlusPainter({this.isClose = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.5
      ..strokeCap = StrokeCap.square;

    canvas.drawLine(
      Offset(0, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
    if (!isClose) {
      canvas.drawLine(
        Offset(size.width / 2, 0),
        Offset(size.width / 2, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_PlusPainter oldDelegate) =>
      oldDelegate.isClose != isClose;
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = Colors.black);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) => false;
}
