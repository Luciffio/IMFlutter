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
  Future<void> sendMessage(String text) async {
    // TODO: forward to Telegram via MTProto
    // The message is already shown locally — nothing to do here yet.
  }

  @override
  Future<void> disconnect() async {
    await _controller.close();
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

    return [
      ChatSummary(
        id: 'phantom-thieves',
        title: 'After school',
        updatedAt: DateTime(2016, 4, 19),
        participants: const [ann, ryuji, yusuke],
        avatarLabel: 'PT',
        isPinned: true,
        unreadCount: 3,
      ),
      ChatSummary(
        id: 'ann',
        title: 'Calling card?',
        updatedAt: DateTime(2016, 4, 18),
        participants: const [ann],
        avatarLabel: 'A',
        isPinned: true,
        unreadCount: 1,
      ),
      ChatSummary(
        id: 'group-today',
        title: 'So tired...',
        updatedAt: DateTime(2016, 4, 17),
        participants: const [ryuji, yusuke],
        avatarLabel: 'RY',
      ),
      ChatSummary(
        id: 'yusuke',
        title: 'Palace?',
        updatedAt: DateTime(2016, 4, 16),
        participants: const [yusuke],
        avatarLabel: 'Y',
        activity: ChatActivity.online,
      ),
      ChatSummary(
        id: 'ryuji',
        title: 'Ran into Kamoshida',
        updatedAt: DateTime(2016, 4, 15),
        participants: const [ryuji],
        avatarLabel: 'R',
      ),
      ChatSummary(
        id: 'ann-private',
        title: 'I saw Shiho today...',
        updatedAt: DateTime(2016, 4, 14),
        participants: const [ann],
        avatarLabel: 'A',
      ),
      ChatSummary(
        id: 'velvet-channel',
        title: 'Velvet Room News',
        updatedAt: DateTime(2016, 4, 13),
        participants: const [],
        avatarLabel: 'VR',
      ),
    ];
  }
}
