import '../models/message.dart';
import 'chat_repository.dart';

/// Telegram backend — replace [MockChatRepository] with this in main.dart
/// once the integration is ready.
///
/// ── Integration plan ──────────────────────────────────────────────────────
///
/// 1. Add a TDLib package to pubspec.yaml, e.g.:
///      tdlib: ^0.x.x        # https://pub.dev/packages/tdlib
///      telegram_client: ...  # alternative pure-Dart client
///
/// 2. [connect] — authenticate:
///      - Initialise TDLib with apiId / apiHash
///      - Handle the auth flow: phone number → SMS code → 2FA password
///      - Store the session so the user only logs in once
///
/// 3. [sendMessage] — forward to Telegram:
///      tdlib.sendMessage(chatId: _activeChatId, text: text)
///
/// 4. [incomingMessages] — receive updates:
///      - Subscribe to TDLib updateNewMessage events
///      - Map TDLib Message → local Message model
///      - Push into the stream so ChatScreen can call addMessage()
///
/// 5. Swap in main.dart:
///      _chatRepository = TelegramRepository(
///        apiId: const int.fromEnvironment('TG_API_ID'),
///        apiHash: const String.fromEnvironment('TG_API_HASH'),
///      );
///
/// ──────────────────────────────────────────────────────────────────────────
class TelegramRepository implements ChatRepository {
  final int apiId;
  final String apiHash;

  // The chat that is currently open in the UI.
  // Set this when the user navigates to a conversation.
  int? activeChatId;

  TelegramRepository({required this.apiId, required this.apiHash});

  @override
  Future<void> connect() {
    // TODO: init TDLib, run auth flow
    throw UnimplementedError('TelegramRepository.connect()');
  }

  @override
  Future<void> sendMessage(String text) {
    // TODO: tdlib.sendMessage(chatId: activeChatId!, text: text)
    throw UnimplementedError('TelegramRepository.sendMessage()');
  }

  @override
  Stream<Message> get incomingMessages {
    // TODO: map TDLib updateNewMessage → Message and yield into stream
    throw UnimplementedError('TelegramRepository.incomingMessages');
  }

  @override
  Future<void> disconnect() {
    // TODO: tdlib.close()
    throw UnimplementedError('TelegramRepository.disconnect()');
  }
}
