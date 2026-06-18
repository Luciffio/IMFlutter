import '../models/chat_summary.dart';
import '../models/message.dart';

/// Abstraction over the chat backend.
///
/// Active implementation: [MockChatRepository] (no real server).
/// Future implementation: [TelegramRepository] — swap in main.dart when ready.
abstract class ChatRepository {
  /// Send a text message to the active chat.
  Future<void> sendMessage(String text);

  /// Stream of messages received from other participants.
  Stream<Message> get incomingMessages;

  /// Establish connection to the backend (auth, subscribe to updates, etc.)
  Future<void> connect();

  /// Clean up connections and resources.
  Future<void> disconnect();

  /// List of chats for the current user, ordered by [ChatSummary.updatedAt]
  /// descending.  The chat list screen calls this once on open.
  Future<List<ChatSummary>> getChats();
}
