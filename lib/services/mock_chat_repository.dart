import 'dart:async';

import 'package:flutter/material.dart';

import '../models/auth_session.dart';
import '../models/chat_summary.dart';
import '../models/message.dart';
import 'chat_repository.dart';

/// In-memory backend used until Telegram is wired in.
///
/// It keeps mutable chat state, per-chat histories, and emits live chat-list
/// updates so the UI already behaves like it is backed by a real service.
class MockChatRepository implements ChatRepository {
  final _messageController = StreamController<Message>.broadcast();
  final _messageUpdateController = StreamController<Message>.broadcast();
  final _typingController = StreamController<ChatTypingUpdate>.broadcast();
  final _chatController = StreamController<List<ChatSummary>>.broadcast();
  final _authController = StreamController<AuthSessionState>.broadcast();

  final _messagesByChat = <String, List<Message>>{};
  var _chats = <ChatSummary>[];
  var _authState = const AuthSessionState.ready();
  var _messageSerial = 0;
  bool _connected = false;

  @override
  Stream<Message> get incomingMessages => _messageController.stream;

  @override
  Stream<Message> get messageUpdates => _messageUpdateController.stream;

  @override
  Stream<ChatTypingUpdate> get typingUpdates => _typingController.stream;

  @override
  Stream<List<ChatSummary>> get chats => _chatController.stream;

  @override
  Stream<AuthSessionState> get authState => _authController.stream;

  @override
  Future<void> connect() async {
    if (_connected) return;
    _connected = true;
    _seed();
    _emitAuth();
    _emitChats();
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    final sentAt = DateTime.now();
    final message = Message(
      id: _nextMessageId(),
      chatId: chatId,
      sender: Sender.ren,
      text: text,
      createdAt: sentAt,
      status: MessageDeliveryStatus.sent,
    );

    _messagesFor(chatId).add(message);
    _updateChat(
      chatId,
      (chat) => chat.copyWith(
        updatedAt: sentAt,
        lastMessagePreview: _previewFor(message),
        lastOutgoingAt: sentAt,
        unreadCount: 0,
      ),
    );
    _emitChats();
  }

  @override
  Future<List<Message>> sendPhotos(
    String chatId,
    List<String> paths, {
    String caption = '',
  }) async {
    if (paths.isEmpty) return const [];
    final message = Message(
      id: _nextMessageId(),
      chatId: chatId,
      sender: Sender.ren,
      text: caption,
      createdAt: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      imagePath: paths.first,
      albumImagePaths: paths.length > 1 ? List.unmodifiable(paths) : const [],
    );
    _messagesFor(chatId).add(message);
    return [message];
  }

  @override
  Future<Message> sendFile(
    String chatId,
    String path, {
    required String name,
    required int size,
    String caption = '',
  }) async {
    final message = Message(
      id: _nextMessageId(),
      chatId: chatId,
      sender: Sender.ren,
      text: caption,
      createdAt: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      filePath: path,
      fileName: name,
      fileSize: size,
    );
    _messagesFor(chatId).add(message);
    return message;
  }

  @override
  Future<Message> sendGif(
    String chatId,
    String path, {
    String caption = '',
  }) async {
    final message = Message(
      id: _nextMessageId(),
      chatId: chatId,
      sender: Sender.ren,
      text: caption,
      createdAt: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      gifPath: path,
    );
    _messagesFor(chatId).add(message);
    return message;
  }

  @override
  Future<Message> sendSticker(String chatId, String path) async {
    final message = Message(
      id: _nextMessageId(),
      chatId: chatId,
      sender: Sender.ren,
      createdAt: DateTime.now(),
      status: MessageDeliveryStatus.sent,
      stickerPath: path,
    );
    _messagesFor(chatId).add(message);
    return message;
  }

  @override
  Future<void> disconnect() async {
    await _messageController.close();
    await _messageUpdateController.close();
    await _typingController.close();
    await _chatController.close();
    await _authController.close();
  }

  @override
  Future<List<ChatSummary>> getChats() async {
    if (!_connected) await connect();
    return _sortedChats();
  }

  @override
  Future<List<Message>> getMessages(String chatId) async {
    if (!_connected) await connect();
    return List.unmodifiable(_messagesFor(chatId));
  }

  @override
  Future<List<Message>> getMessagesBefore(
    String chatId,
    String beforeMessageId,
  ) async {
    return const [];
  }

  @override
  Future<void> markChatOpened(String chatId) async {
    _updateChat(
      chatId,
      (chat) => chat.copyWith(unreadCount: 0, isMarkedUnread: false),
    );
    _emitChats();
  }

  @override
  Future<void> setChatMarkedUnread(String chatId, bool isMarkedUnread) async {
    _updateChat(
      chatId,
      (chat) => chat.copyWith(isMarkedUnread: isMarkedUnread),
    );
    _emitChats();
  }

  @override
  Future<void> setChatPinned(String chatId, bool isPinned) async {
    _updateChat(
      chatId,
      (chat) => chat.copyWith(
        pinnedAt: isPinned ? DateTime.now() : null,
        clearPinnedAt: !isPinned,
      ),
    );
    _emitChats();
  }

  @override
  Future<void> setChatArchived(String chatId, bool isArchived) async {
    _updateChat(chatId, (chat) => chat.copyWith(isArchived: isArchived));
    _emitChats();
  }

  @override
  Future<AuthSessionState> getAuthState() async {
    return _authState;
  }

  @override
  Future<void> startAuthentication() async {
    _setAuthState(const AuthSessionState.waitPhone());
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {
    final value = phoneNumber.trim();
    if (value.isEmpty) {
      _setAuthState(
        _authState.copyWith(
          stage: AuthStage.waitPhone,
          errorMessage: 'ENTER PHONE NUMBER',
        ),
      );
      return;
    }

    _setAuthState(
      AuthSessionState(stage: AuthStage.waitCode, phoneNumber: value),
    );
  }

  @override
  Future<void> submitEmailAddress(String emailAddress) async {
    _setAuthState(
      const AuthSessionState(
        stage: AuthStage.waitEmailCode,
        emailAddressPattern: 'm***@example.com',
        canResendCode: true,
      ),
    );
  }

  @override
  Future<void> submitEmailCode(String code) async {
    _setAuthState(_authState.copyWith(stage: AuthStage.waitCode));
  }

  @override
  Future<void> submitCode(String code) async {
    final value = code.trim();
    if (value.isEmpty) {
      _setAuthState(
        _authState.copyWith(
          stage: AuthStage.waitCode,
          errorMessage: 'ENTER CODE',
        ),
      );
      return;
    }

    _setAuthState(_authState.copyWith(stage: AuthStage.waitPassword));
  }

  @override
  Future<void> submitPassword(String password) async {
    _setAuthState(const AuthSessionState.ready());
  }

  @override
  Future<void> submitRegistration(String firstName, String lastName) async {
    _setAuthState(const AuthSessionState.ready());
  }

  @override
  Future<void> resendAuthenticationCode() async {}

  @override
  Future<void> requestQrCodeAuthentication() async {
    _setAuthState(
      const AuthSessionState(
        stage: AuthStage.waitOtherDevice,
        otherDeviceLink: 'tg://login?token=mock',
      ),
    );
  }

  @override
  Future<void> cancelAuthentication() async {
    _setAuthState(const AuthSessionState.ready());
  }

  @override
  Future<void> signOut() async {
    _setAuthState(const AuthSessionState.signedOut());
  }

  void _seed() {
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

    _chats = [
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

    _messagesByChat
      ..clear()
      ..addAll({
        'phantom-thieves': _stampMessages('phantom-thieves', [
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
            sender: Sender.ryuji,
            text:
                'He talked to Iida and Nishiyama over at Central Street, right?',
          ),
        ]),
        'ann': _stampMessages('ann', [
          const Message(
            sender: Sender.ann,
            text:
                "It's kinda scary to think people like that are all around us in this city...",
          ),
          const Message(sender: Sender.ren, text: 'We will handle it.'),
          const Message(
            sender: Sender.ann,
            text: "That's not a bad idea. Just be careful, okay?",
          ),
        ]),
        'group-today': _stampMessages('group-today', [
          const Message(sender: Sender.ryuji, text: 'Man, I am beat.'),
          const Message(
            sender: Sender.yusuke,
            text: 'Fatigue is no excuse for poor observation.',
          ),
          const Message(
            sender: Sender.ryuji,
            text: "Well guys, we gotta brace ourselves. We're up against it.",
          ),
        ]),
        'yusuke': _stampMessages('yusuke', [
          const Message(
            sender: Sender.yusuke,
            text:
                'Indeed, it seems that is where our target waits. But then... who should be the one to go?',
          ),
          const Message(
            sender: Sender.ren,
            text: 'We can decide after school.',
          ),
        ]),
        'ryuji': _stampMessages('ryuji', [
          const Message(
            sender: Sender.ryuji,
            text:
                'He talked to Iida and Nishiyama over at Central Street, right?',
          ),
          const Message(sender: Sender.ren, text: 'Yeah. That tracks.'),
        ]),
        'ann-private': _stampMessages('ann-private', [
          const Message(sender: Sender.ann, text: 'I saw Shiho today...'),
          const Message(sender: Sender.ren, text: 'How did she look?'),
        ]),
        'velvet-channel': _stampMessages('velvet-channel', [
          const Message(sender: Sender.yusuke, text: 'Look at the rankings!'),
          const Message(
            sender: Sender.ann,
            imagePath: 'assets/images/template.jpg',
          ),
        ]),
      });
  }

  List<Message> _stampMessages(String chatId, List<Message> messages) {
    final base = DateTime(2016, 4, 19, 15);
    return [
      for (var i = 0; i < messages.length; i++)
        _copyMessage(
          messages[i],
          id: _nextMessageId(),
          chatId: chatId,
          createdAt: base.add(Duration(minutes: i * 4)),
        ),
    ];
  }

  List<Message> _messagesFor(String chatId) {
    return _messagesByChat.putIfAbsent(chatId, () => <Message>[]);
  }

  void _updateChat(String chatId, ChatSummary Function(ChatSummary) update) {
    _chats = [
      for (final chat in _chats) chat.id == chatId ? update(chat) : chat,
    ];
  }

  List<ChatSummary> _sortedChats() {
    final sorted = [..._chats];
    sorted.sort((a, b) {
      final pinnedA = a.pinnedAt;
      final pinnedB = b.pinnedAt;
      if (pinnedA != null || pinnedB != null) {
        if (pinnedA == null) return 1;
        if (pinnedB == null) return -1;
        return pinnedB.compareTo(pinnedA);
      }
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return List.unmodifiable(sorted);
  }

  void _emitChats() {
    if (!_chatController.isClosed) _chatController.add(_sortedChats());
  }

  void _setAuthState(AuthSessionState state) {
    _authState = state;
    _emitAuth();
  }

  void _emitAuth() {
    if (!_authController.isClosed) _authController.add(_authState);
  }

  String _nextMessageId() => 'mock-${++_messageSerial}';

  String _previewFor(Message message) {
    if (message.text.trim().isNotEmpty) return message.text.trim();
    return switch (message.kind) {
      MessageKind.image => 'Photo',
      MessageKind.file => message.fileName ?? 'File',
      MessageKind.gif => 'GIF',
      MessageKind.sticker => 'Sticker',
      MessageKind.text => '',
    };
  }

  Message _copyMessage(
    Message message, {
    String? id,
    String? chatId,
    DateTime? createdAt,
    MessageDeliveryStatus? status,
  }) {
    return Message(
      id: id ?? message.id,
      chatId: chatId ?? message.chatId,
      sender: message.sender,
      text: message.text,
      createdAt: createdAt ?? message.createdAt,
      status: status ?? message.status,
      imagePath: message.imagePath,
      stickerPath: message.stickerPath,
      gifPath: message.gifPath,
      filePath: message.filePath,
      fileName: message.fileName,
      fileSize: message.fileSize,
    );
  }
}
