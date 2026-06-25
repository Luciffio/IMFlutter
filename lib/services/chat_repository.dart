import '../models/auth_session.dart';
import '../models/chat_summary.dart';
import '../models/message.dart';

/// Abstraction over the chat backend.
///
/// Active implementation: [MockChatRepository] (no real server).
/// Future implementation: [TelegramRepository] — swap in main.dart when ready.
abstract class ChatRepository {
  /// Send a text message to a concrete chat.
  Future<void> sendMessage(String chatId, String text);

  /// Stream of messages received from other participants.
  Stream<Message> get incomingMessages;

  /// Live chat list updates. Backends should emit whenever unread counts,
  /// ordering, pinned state, previews, or activity changes.
  Stream<List<ChatSummary>> get chats;

  /// Authentication/session updates. Telegram will map TDLib authorization
  /// states into this stream.
  Stream<AuthSessionState> get authState;

  /// Establish connection to the backend (auth, subscribe to updates, etc.)
  Future<void> connect();

  /// Clean up connections and resources.
  Future<void> disconnect();

  /// List of chats for the current user, ordered by [ChatSummary.updatedAt]
  /// descending.  The chat list screen calls this once on open.
  Future<List<ChatSummary>> getChats();

  /// Message history for a concrete chat. The mock can return demo messages;
  /// Telegram will map this to getChatHistory.
  Future<List<Message>> getMessages(String chatId);

  /// Mark a chat as opened/read from the app's point of view.
  Future<void> markChatOpened(String chatId);

  /// Current authentication/session state.
  Future<AuthSessionState> getAuthState();

  /// Start or resume the login flow.
  Future<void> startAuthentication();

  Future<void> submitPhoneNumber(String phoneNumber);

  Future<void> submitCode(String code);

  Future<void> submitPassword(String password);

  Future<void> cancelAuthentication();

  Future<void> signOut();
}
