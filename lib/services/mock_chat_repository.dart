import 'dart:async';
import 'package:flutter/material.dart';
import '../models/chat_summary.dart';
import '../models/message.dart';
import 'chat_repository.dart';

/// No-op stub — used until the real Telegram backend is wired up.
///
/// Sent messages are rendered locally by [TranscriptState.addMessage] before
/// this is called, so this only needs to forward them to a real server once
/// [TelegramRepository] is swapped in.
class MockChatRepository implements ChatRepository {
  final _controller = StreamController<Message>.broadcast();

  @override
  Stream<Message> get incomingMessages => _controller.stream;

  @override
  Future<void> connect() async {
    // TODO: initialise TDLib / open Telegram session
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    // TODO: forward to Telegram via MTProto
    // The message is already shown locally — nothing to do here yet.
  }

  @override
  Future<void> disconnect() async {
    await _controller.close();
  }

  @override
  Future<List<Message>> getMessages(String chatId) async {
    return kMessages
        .map(
          (message) => Message(
            id: message.id,
            chatId: chatId,
            sender: message.sender,
            text: message.text,
            createdAt: message.createdAt,
            status: message.status,
            imagePath: message.imagePath,
            stickerPath: message.stickerPath,
            gifPath: message.gifPath,
            filePath: message.filePath,
            fileName: message.fileName,
            fileSize: message.fileSize,
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> markChatOpened(String chatId) async {
    // TODO: persist read state once chats are mutable/live.
  }

  @override
  Future<List<ChatSummary>> getChats() async {
    // P5-themed placeholders.  Each chat reuses bundled portraits so the
    // avatar badges render with real faces until Telegram contacts are wired.
    const ann = ChatParticipant(
      name: 'Ann',
      portraitAsset: 'assets/portraits/ann.png',
      color: Color(0xFFFE93C9),
    );
    const ryuji = ChatParticipant(
      name: 'Ryuji',
      portraitAsset: 'assets/portraits/ryuji.png',
      color: Color(0xFFF0EA40),
    );
    const yusuke = ChatParticipant(
      name: 'Yusuke',
      portraitAsset: 'assets/portraits/yusuke.png',
      color: Color(0xFF1BC8F9),
    );

    final chats = [
      ChatSummary(
        id: 'phantom-thieves',
        title: 'After school',
        type: ChatType.group,
        updatedAt: DateTime(2016, 4, 19),
        participants: const [ann, ryuji, yusuke],
        lastMessagePreview: 'We have to find them tomorrow for sure.',
        avatarLabel: 'PT',
        pinnedAt: DateTime(2016, 4, 19, 16),
        lastIncomingAt: DateTime(2016, 4, 19, 15, 42),
        lastOutgoingAt: DateTime(2016, 4, 19, 14, 10),
      ),
      ChatSummary(
        id: 'ann',
        title: 'Calling card?',
        type: ChatType.direct,
        updatedAt: DateTime(2016, 4, 18),
        participants: const [ann],
        lastMessagePreview: "It's kinda scary to think people like that.",
        avatarLabel: 'A',
        pinnedAt: DateTime(2016, 4, 18, 22),
        lastIncomingAt: DateTime(2016, 4, 18, 21, 20),
        lastOutgoingAt: DateTime(2016, 4, 18, 19, 45),
      ),
      ChatSummary(
        id: 'group-today',
        title: 'So tired...',
        type: ChatType.group,
        updatedAt: DateTime(2016, 4, 17),
        participants: const [ryuji, yusuke],
        lastMessagePreview: 'Well guys, we gotta brace ourselves.',
        avatarLabel: 'RY',
        lastIncomingAt: DateTime(2016, 4, 17, 18, 8),
        lastOutgoingAt: DateTime(2016, 4, 17, 17, 55),
        unreadCount: 2,
      ),
      ChatSummary(
        id: 'yusuke',
        title: 'Palace?',
        type: ChatType.direct,
        updatedAt: DateTime(2016, 4, 16),
        participants: const [yusuke],
        lastMessagePreview: 'Indeed, it seems that is where our target waits.',
        avatarLabel: 'Y',
        activity: ChatActivity.online,
        lastIncomingAt: DateTime(2016, 4, 16, 22, 30),
        lastOutgoingAt: DateTime(2016, 4, 16, 22, 34),
      ),
      ChatSummary(
        id: 'ryuji',
        title: 'Ran into Kamoshida',
        type: ChatType.direct,
        updatedAt: DateTime(2016, 4, 15),
        participants: const [ryuji],
        lastMessagePreview: 'He talked to Iida and Nishiyama, right?',
        avatarLabel: 'R',
        lastIncomingAt: DateTime(2016, 4, 15, 17, 30),
        lastOutgoingAt: DateTime(2016, 4, 15, 17, 38),
      ),
      ChatSummary(
        id: 'ann-private',
        title: 'I saw Shiho today...',
        type: ChatType.direct,
        updatedAt: DateTime(2016, 4, 14),
        participants: const [ann],
        lastMessagePreview: "That's not a bad idea.",
        avatarLabel: 'A',
        lastIncomingAt: DateTime(2016, 4, 14, 20, 4),
        lastOutgoingAt: DateTime(2016, 4, 14, 18, 12),
      ),
      ChatSummary(
        id: 'velvet-channel',
        title: 'Velvet Room News',
        type: ChatType.channel,
        updatedAt: DateTime(2016, 4, 13),
        participants: const [],
        lastMessagePreview: 'Look at the rankings!',
        avatarLabel: 'VR',
        lastIncomingAt: DateTime(2016, 4, 13, 9),
        unreadCount: 1,
      ),
    ];

    chats.sort((a, b) {
      final pinnedA = a.pinnedAt;
      final pinnedB = b.pinnedAt;
      if (pinnedA != null || pinnedB != null) {
        if (pinnedA == null) return 1;
        if (pinnedB == null) return -1;
        return pinnedB.compareTo(pinnedA);
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return chats;
  }
}
