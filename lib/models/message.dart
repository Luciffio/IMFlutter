import 'package:flutter/material.dart';

enum Sender {
  ann,
  ryuji,
  yusuke,
  ren, // player character — no avatar
}

extension SenderInfo on Sender {
  Color get color {
    switch (this) {
      case Sender.ann:
        return const Color(0xFFFE93C9);
      case Sender.ryuji:
        return const Color(0xFFF0EA40);
      case Sender.yusuke:
        return const Color(0xFF1BC8F9);
      case Sender.ren:
        return Colors.transparent;
    }
  }

  String? get portraitAsset {
    switch (this) {
      case Sender.ann:
        return 'assets/portraits/ann.png';
      case Sender.ryuji:
        return 'assets/portraits/ryuji.png';
      case Sender.yusuke:
        return 'assets/portraits/yusuke.png';
      case Sender.ren:
        return null;
    }
  }
}

enum MessageDeliveryStatus { sending, sent, delivered, read, failed }

enum MessageKind { text, image, file, gif, sticker }

class Message {
  final String? id;
  final String? chatId;
  final Sender sender;
  final String text;
  final DateTime? createdAt;
  final MessageDeliveryStatus status;
  final String? imagePath;
  final String? stickerPath;
  final String? gifPath;
  final String? filePath;
  final String? fileName;
  final int? fileSize;

  const Message({
    this.id,
    this.chatId,
    required this.sender,
    this.text = '',
    this.createdAt,
    this.status = MessageDeliveryStatus.delivered,
    this.imagePath,
    this.stickerPath,
    this.gifPath,
    this.filePath,
    this.fileName,
    this.fileSize,
  });

  bool get isImage => imagePath != null;
  bool get isSticker => stickerPath != null;
  bool get isGif => gifPath != null;
  bool get isFile => filePath != null;
  bool get isAnimatedMedia => isSticker || isGif;
  String? get animatedMediaPath => gifPath ?? stickerPath;

  MessageKind get kind {
    if (isImage) return MessageKind.image;
    if (isFile) return MessageKind.file;
    if (isGif) return MessageKind.gif;
    if (isSticker) return MessageKind.sticker;
    return MessageKind.text;
  }

  bool get isOutgoing => sender == Sender.ren;
}

final List<Message> kMessages = [
  const Message(
    sender: Sender.ann,
    text:
        'We have to find them tomorrow for sure. This is the only lead we have right now.',
  ),
  const Message(
    sender: Sender.yusuke,
    text:
        'Yes. It is highly likely that this part-time solicitor is somehow related to the mafia.',
  ),
  const Message(
    sender: Sender.yusuke,
    text: 'If we tail him, he may lead us straight back to his boss.',
  ),
  const Message(
    sender: Sender.ryuji,
    text: 'He talked to Iida and Nishiyama over at Central Street, right?',
  ),
  const Message(
    sender: Sender.yusuke,
    text:
        'Indeed, it seems that is where our target waits. But then... who should be the one to go?',
  ),
  const Message(sender: Sender.ren, text: 'Morgana, I choose you.'),
  const Message(
    sender: Sender.ann,
    text:
        "That's not a bad idea. Cats have nine lives, right? Morgana can spare one for this.",
  ),
  const Message(
    sender: Sender.ryuji,
    text:
        "Wouldn't the mafia get caught off guard if they had a cat coming to deliver for 'em?",
  ),
  const Message(
    sender: Sender.yusuke,
    text: 'In other words, Maaku will be going. I have no objections.',
  ),
  const Message(
    sender: Sender.yusuke,
    text:
        'Tricking people and using that as blackmail… These bastards are true cowards.',
  ),
  const Message(
    sender: Sender.ann,
    text:
        "It's kinda scary to think people like that are all around us in this city...",
  ),
  const Message(
    sender: Sender.ryuji,
    text:
        "Well guys, we gotta brace ourselves. We're up against a serious criminal here.",
  ),
  const Message(
    sender: Sender.ann,
    text: "Here's our commemorative photo from the summer festival!",
  ),
  const Message(sender: Sender.ann, imagePath: 'assets/images/template.jpg'),
  const Message(
    sender: Sender.ryuji,
    stickerPath: 'assets/stickers/sticker.webp',
  ),
  const Message(
    sender: Sender.ann,
    stickerPath: 'assets/stickers/sticker.webm',
  ),
  const Message(
    sender: Sender.yusuke,
    stickerPath: 'assets/stickers/persona4.gif',
  ),
];
