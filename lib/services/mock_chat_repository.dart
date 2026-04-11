import 'dart:async';
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
}
