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

  Future<List<Message>> sendPhotos(
    String chatId,
    List<String> paths, {
    String caption = '',
  });

  Future<Message> sendFile(
    String chatId,
    String path, {
    required String name,
    required int size,
    String caption = '',
  });

  Future<Message> sendGif(String chatId, String path, {String caption = ''});

  Future<Message> sendSticker(String chatId, String path);

  /// Stream of messages received from other participants.
  Stream<Message> get incomingMessages;

  /// Existing messages whose downloaded media became available locally.
  Stream<Message> get messageUpdates;

  Stream<ChatTypingUpdate> get typingUpdates;

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

  /// Older messages before the currently oldest visible message.
  Future<List<Message>> getMessagesBefore(
    String chatId,
    String beforeMessageId,
  );

  /// Mark a chat as opened/read from the app's point of view.
  Future<void> markChatOpened(String chatId);

  Future<void> setChatMarkedUnread(String chatId, bool isMarkedUnread);

  Future<void> setChatPinned(String chatId, bool isPinned);

  Future<void> setChatArchived(String chatId, bool isArchived);

  /// Current authentication/session state.
  Future<AuthSessionState> getAuthState();

  /// Start or resume the login flow.
  Future<void> startAuthentication();

  Future<void> submitPhoneNumber(String phoneNumber);

  Future<void> submitEmailAddress(String emailAddress);

  Future<void> submitEmailCode(String code);

  Future<void> submitCode(String code);

  Future<void> submitPassword(String password);

  Future<void> submitRegistration(String firstName, String lastName);

  Future<void> resendAuthenticationCode();

  Future<void> requestQrCodeAuthentication();

  Future<void> cancelAuthentication();

  Future<void> signOut();
}
