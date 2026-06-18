import '../models/chat_summary.dart';
import '../models/message.dart';
import 'chat_repository.dart';

/// Telegram backend — replace [MockChatRepository] with this in main.dart
/// once the integration is ready.
///
/// ── Integration plan ──────────────────────────────────────────────────────
///
/// 1. Pick a client library:
///      tdlib: ^0.x.x         # https://pub.dev/packages/tdlib — bundles
///                              libtdjson for iOS/Android/desktop
///      telegram_client: ...  # pure-Dart MTProto alternative
///
/// 2. [connect] — initialise the client and run the auth flow:
///      - TdlibParameters(apiId, apiHash, systemLanguageCode, ...)
///      - Handle authorizationStateWaitPhoneNumber → send phone
///      - Handle authorizationStateWaitCode        → user enters SMS code
///      - Handle authorizationStateWaitPassword    → 2FA password
///      - Handle authorizationStateReady           → ready to use
///      - Persist the session DB so the user logs in once.
///
/// 3. [getChats] — load the chat list:
///      - Call getChats(chatList: chatListMain, limit: 100)
///      - For each id → getChat(id) → getUser(id) / getBasicGroup / getSupergroup
///      - Download profile photos (downloadFile on the small photo)
///      - Map to [ChatSummary] + [ChatParticipant]
///
/// 4. [sendMessage] — forward to Telegram:
///      tdlib.sendMessage(chatId: activeChatId, text: text)
///
/// 5. [incomingMessages] — stream updateNewMessage events:
///      - Subscribe, map TDLib Message → local [Message] model
///      - Push into the stream so ChatScreen can call addMessage()
///
/// 6. Swap in main.dart:
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

  @override
  Future<List<ChatSummary>> getChats() {
    // TODO: tdlib.getChats(chatList: chatListMain, limit: 100)
    //       → resolve titles/photos → map to [ChatSummary]
    throw UnimplementedError('TelegramRepository.getChats()');
  }
}
