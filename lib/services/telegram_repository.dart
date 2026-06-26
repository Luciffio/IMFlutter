import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/auth_session.dart';
import '../models/chat_summary.dart';
import '../models/message.dart';
import 'chat_repository.dart';
import 'tdlib_gateway.dart';

class TelegramRepository implements ChatRepository {
  final int apiId;
  final String apiHash;
  final TdlibGateway _gateway;

  final _messageController = StreamController<Message>.broadcast();
  final _chatController = StreamController<List<ChatSummary>>.broadcast();
  final _authController = StreamController<AuthSessionState>.broadcast();

  final _chatsById = <String, ChatSummary>{};
  final _messagesByChat = <String, List<Message>>{};

  StreamSubscription<TdJson>? _updatesSub;
  AuthSessionState _authState = const AuthSessionState.signedOut();
  var _connected = false;
  var _ready = false;

  TelegramRepository({
    required this.apiId,
    required this.apiHash,
    TdlibGateway? gateway,
  }) : _gateway = gateway ?? TdlibGateway();

  @override
  Stream<Message> get incomingMessages => _messageController.stream;

  @override
  Stream<List<ChatSummary>> get chats => _chatController.stream;

  @override
  Stream<AuthSessionState> get authState => _authController.stream;

  @override
  Future<void> connect() async {
    if (_connected) return;
    _connected = true;

    if (apiId == 0 || apiHash.isEmpty) {
      _setAuthState(
        const AuthSessionState(
          stage: AuthStage.signedOut,
          errorMessage: 'TG_API_ID / TG_API_HASH REQUIRED',
        ),
      );
      return;
    }

    await _gateway.initialize();
    _updatesSub = _gateway.updates.listen(_handleUpdate);
    final state = await _gateway.invoke({'@type': 'getAuthorizationState'});
    _handleAuthorizationState(state['authorization_state'] as TdJson? ?? state);
  }

  @override
  Future<void> disconnect() async {
    await _updatesSub?.cancel();
    await _gateway.close();
    await _messageController.close();
    await _chatController.close();
    await _authController.close();
  }

  @override
  Future<AuthSessionState> getAuthState() async {
    return _authState;
  }

  @override
  Future<void> startAuthentication() async {
    await connect();
    if (_ready) {
      _setAuthState(const AuthSessionState.ready());
      return;
    }

    final state = await _gateway.invoke({'@type': 'getAuthorizationState'});
    _handleAuthorizationState(state['authorization_state'] as TdJson? ?? state);
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {
    await _invokeAuth({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phoneNumber.trim(),
      'settings': null,
    });
  }

  @override
  Future<void> submitCode(String code) async {
    await _invokeAuth({
      '@type': 'checkAuthenticationCode',
      'code': code.trim(),
    });
  }

  @override
  Future<void> submitPassword(String password) async {
    await _invokeAuth({
      '@type': 'checkAuthenticationPassword',
      'password': password,
    });
  }

  @override
  Future<void> cancelAuthentication() async {
    if (_connected) {
      try {
        _gateway.send({'@type': 'destroy'});
      } catch (_) {
        // The client may already be closed; resetting below creates a fresh one.
      }
    }

    await _updatesSub?.cancel();
    _updatesSub = null;
    _ready = false;
    _connected = false;
    _chatsById.clear();
    _messagesByChat.clear();
    _emitChats();
    _setAuthState(
      const AuthSessionState.waitPhone().copyWith(clearCodeDelivery: true),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _gateway.resetClient();
    unawaited(connect());
  }

  @override
  Future<void> signOut() async {
    await _gateway.invoke({'@type': 'logOut'});
    _ready = false;
    _setAuthState(const AuthSessionState.signedOut());
  }

  @override
  Future<List<ChatSummary>> getChats() async {
    await connect();
    if (!_ready) return _sortedChats();

    final result = await _gateway.invoke({
      '@type': 'getChats',
      'chat_list': null,
      'limit': 80,
    });

    final ids = (result['chat_ids'] as List? ?? const []);
    for (final id in ids.whereType<int>()) {
      final chat = await _gateway.invoke({'@type': 'getChat', 'chat_id': id});
      await _cacheChat(chat);
    }

    _emitChats();
    return _sortedChats();
  }

  @override
  Future<List<Message>> getMessages(String chatId) async {
    await connect();
    if (!_ready) return List.unmodifiable(_messagesByChat[chatId] ?? const []);

    final id = int.tryParse(chatId);
    if (id == null) return const [];

    unawaited(_openChat(id));
    final rawMessages = await _loadChatHistory(id);
    final messages = <Message>[];
    for (final raw in rawMessages.reversed) {
      messages.add(await _mapMessage(raw));
    }
    _messagesByChat[chatId] = messages;
    return List.unmodifiable(messages);
  }

  Future<List<TdJson>> _loadChatHistory(int chatId) async {
    final byId = <int, TdJson>{};
    var fromMessageId = 0;

    for (var page = 0; page < 6; page++) {
      final offset = fromMessageId == 0 ? 0 : -1;
      final result = await _gateway.invoke({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'from_message_id': fromMessageId,
        'offset': offset,
        'limit': 60,
        'only_local': false,
      });

      final messages = (result['messages'] as List? ?? const [])
          .whereType<TdJson>()
          .toList();
      if (messages.isEmpty) break;

      var added = 0;
      for (final message in messages) {
        final id = message['id'];
        if (id is! int || byId.containsKey(id)) continue;
        byId[id] = message;
        added++;
      }

      final oldestId = messages.last['id'];
      if (oldestId is! int || oldestId == fromMessageId) break;
      fromMessageId = oldestId;

      if (byId.length >= 80) break;
      if (added == 0) break;
      if (messages.length <= 1) {
        await Future<void>.delayed(const Duration(milliseconds: 350));
      }
    }

    final sorted = byId.values.toList();
    sorted.sort((a, b) {
      final left = a['id'];
      final right = b['id'];
      if (left is! int || right is! int) return 0;
      return right.compareTo(left);
    });
    return sorted;
  }

  Future<void> _openChat(int chatId) async {
    try {
      await _gateway.invoke({
        '@type': 'openChat',
        'chat_id': chatId,
      }, timeout: const Duration(seconds: 10));
    } catch (_) {
      // History loading still works for chats TDLib can't mark as opened.
    }
  }

  @override
  Future<void> markChatOpened(String chatId) async {
    final id = int.tryParse(chatId);
    if (id == null || !_ready) return;
    await _gateway.invoke({
      '@type': 'viewMessages',
      'chat_id': id,
      'message_ids': const [],
      'source': null,
      'force_read': true,
    });
  }

  @override
  Future<void> sendMessage(String chatId, String text) async {
    await connect();
    final id = int.tryParse(chatId);
    if (id == null || !_ready) return;

    final sent = await _gateway.invoke({
      '@type': 'sendMessage',
      'chat_id': id,
      'message_thread_id': 0,
      'reply_to': null,
      'options': null,
      'reply_markup': null,
      'input_message_content': {
        '@type': 'inputMessageText',
        'text': {'@type': 'formattedText', 'text': text, 'entities': const []},
        'link_preview_options': null,
        'clear_draft': true,
      },
    });

    final message = await _mapMessage(sent);
    _messagesFor(chatId).add(message);
  }

  Future<void> _invokeAuth(TdJson request) async {
    try {
      await _gateway.invoke(request);
    } catch (error) {
      _setAuthState(_authState.copyWith(errorMessage: _authErrorText(error)));
    }
  }

  Future<void> _handleUpdate(TdJson update) async {
    switch (update['@type']) {
      case 'updateAuthorizationState':
        _handleAuthorizationState(update['authorization_state'] as TdJson?);
      case 'updateNewChat':
        await _cacheChat(update['chat'] as TdJson?);
        _emitChats();
      case 'updateChatLastMessage':
        await _refreshChat(update['chat_id']);
      case 'updateChatReadInbox':
      case 'updateChatReadOutbox':
      case 'updateChatUnreadMentionCount':
      case 'updateChatPosition':
        await _refreshChat(update['chat_id']);
      case 'updateNewMessage':
        final raw = update['message'];
        if (raw is TdJson) {
          if (raw['is_outgoing'] == true) {
            await _refreshChat(raw['chat_id']);
            return;
          }
          final message = await _mapMessage(raw);
          _messagesFor(message.chatId ?? '').add(message);
          _messageController.add(message);
          await _refreshChat(raw['chat_id']);
        }
    }
  }

  Future<void> _refreshChat(Object? chatId) async {
    if (chatId is! int || !_ready) return;
    final chat = await _gateway.invoke({'@type': 'getChat', 'chat_id': chatId});
    await _cacheChat(chat);
    _emitChats();
  }

  Future<void> _handleAuthorizationState(TdJson? state) async {
    if (state == null) return;
    switch (state['@type']) {
      case 'authorizationStateWaitTdlibParameters':
        await _sendTdlibParameters();
      case 'authorizationStateWaitPhoneNumber':
        _setAuthState(
          const AuthSessionState.waitPhone().copyWith(clearCodeDelivery: true),
        );
      case 'authorizationStateWaitCode':
        final codeInfo = state['code_info'] as TdJson?;
        _setAuthState(
          _authState.copyWith(
            stage: AuthStage.waitCode,
            phoneNumber: codeInfo?['phone_number'] as String?,
            codeDeliveryMessage: _codeDeliveryMessage(codeInfo),
          ),
        );
      case 'authorizationStateWaitPassword':
        _setAuthState(_authState.copyWith(stage: AuthStage.waitPassword));
      case 'authorizationStateReady':
        _ready = true;
        _setAuthState(const AuthSessionState.ready());
        unawaited(getChats());
      case 'authorizationStateLoggingOut':
      case 'authorizationStateClosing':
        _setAuthState(_authState.copyWith(isLoading: true));
      case 'authorizationStateClosed':
        _ready = false;
        _setAuthState(const AuthSessionState.signedOut());
    }
  }

  Future<void> _sendTdlibParameters() async {
    final supportDir = await getApplicationSupportDirectory();
    final baseDir = Directory('${supportDir.path}/tdlib');
    final filesDir = Directory('${baseDir.path}/files');
    await baseDir.create(recursive: true);
    await filesDir.create(recursive: true);

    await _gateway.invoke({
      '@type': 'setTdlibParameters',
      'use_test_dc': false,
      'database_directory': baseDir.path,
      'files_directory': filesDir.path,
      'database_encryption_key': '',
      'use_file_database': true,
      'use_chat_info_database': true,
      'use_message_database': true,
      'use_secret_chats': false,
      'api_id': apiId,
      'api_hash': apiHash,
      'system_language_code': 'en',
      'device_model': 'Android',
      'system_version': Platform.operatingSystemVersion,
      'application_version': '0.1.1',
    });
  }

  Future<void> _cacheChat(TdJson? raw) async {
    if (raw == null) return;
    final summary = await _mapChat(raw);
    _chatsById[summary.id] = summary;
  }

  Future<ChatSummary> _mapChat(TdJson raw) async {
    final id = raw['id'] as int;
    final lastMessage = raw['last_message'] as TdJson?;
    final lastDate = _dateFromUnix(lastMessage?['date']);
    final isPinned = _isPinned(raw['positions']);
    final isChannel = _isChannel(raw['type']);
    final photoFile = _chatPhotoFile(raw['photo'] as TdJson?);
    final avatarPath = photoFile == null ? null : _localFilePath(photoFile);
    if (avatarPath == null && photoFile != null) {
      unawaited(_hydrateChatAvatar(id.toString(), photoFile));
    }

    return ChatSummary(
      id: id.toString(),
      title: (raw['title'] as String?)?.trim().isNotEmpty == true
          ? raw['title'] as String
          : 'Telegram chat',
      type: isChannel
          ? ChatType.channel
          : _isGroup(raw['type'])
          ? ChatType.group
          : ChatType.direct,
      updatedAt: lastDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      participants: const [],
      lastMessagePreview: _messagePreview(lastMessage),
      avatarPath: avatarPath,
      avatarLabel: _initials(raw['title'] as String?),
      pinnedAt: isPinned ? DateTime.now() : null,
      lastIncomingAt: _isOutgoing(lastMessage) ? null : lastDate,
      lastOutgoingAt: _isOutgoing(lastMessage) ? lastDate : null,
      unreadCount: raw['unread_count'] as int? ?? 0,
    );
  }

  Future<void> _hydrateChatAvatar(String chatId, TdJson file) async {
    final path = await _downloadFilePath(file);
    if (path == null) return;

    final current = _chatsById[chatId];
    if (current == null || current.avatarPath == path) return;

    _chatsById[chatId] = current.copyWith(avatarPath: path);
    _emitChats();
  }

  Future<Message> _mapMessage(TdJson raw) async {
    final outgoing = raw['is_outgoing'] == true;
    final chatId = (raw['chat_id'] as int?)?.toString();
    final content = raw['content'] as TdJson?;
    final imagePath = content?['@type'] == 'messagePhoto'
        ? await _downloadFilePath(
            _largestPhotoFile(content?['photo'] as TdJson?),
          )
        : null;
    final stickerPath = content?['@type'] == 'messageSticker'
        ? await _downloadFilePath(_stickerFile(content?['sticker'] as TdJson?))
        : null;
    final gifPath = content?['@type'] == 'messageAnimation'
        ? await _downloadFilePath(
            _animationFile(content?['animation'] as TdJson?),
          )
        : null;

    return Message(
      id: (raw['id'] as int?)?.toString(),
      chatId: chatId,
      sender: outgoing ? Sender.ren : Sender.ann,
      text: imagePath == null && stickerPath == null && gifPath == null
          ? _messagePreview(raw)
          : _captionText(content),
      createdAt: _dateFromUnix(raw['date']),
      status: outgoing
          ? MessageDeliveryStatus.sent
          : MessageDeliveryStatus.delivered,
      imagePath: imagePath,
      stickerPath: stickerPath,
      gifPath: gifPath,
      avatarPath: outgoing ? null : _chatsById[chatId]?.avatarPath,
    );
  }

  List<Message> _messagesFor(String chatId) {
    return _messagesByChat.putIfAbsent(chatId, () => <Message>[]);
  }

  List<ChatSummary> _sortedChats() {
    final sorted = _chatsById.values.toList();
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return List.unmodifiable(sorted);
  }

  void _emitChats() {
    if (!_chatController.isClosed) _chatController.add(_sortedChats());
  }

  void _setAuthState(AuthSessionState state) {
    _authState = state;
    if (!_authController.isClosed) _authController.add(state);
  }

  DateTime? _dateFromUnix(Object? value) {
    if (value is! int || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  TdJson? _chatPhotoFile(TdJson? photo) {
    final small = photo?['small'];
    return small is TdJson ? small : null;
  }

  TdJson? _largestPhotoFile(TdJson? photo) {
    final sizes = photo?['sizes'];
    if (sizes is! List) return null;

    TdJson? bestFile;
    var bestArea = 0;
    for (final size in sizes.whereType<TdJson>()) {
      final width = size['width'];
      final height = size['height'];
      final file = size['photo'];
      if (width is! int || height is! int || file is! TdJson) continue;

      final area = width * height;
      if (area > bestArea) {
        bestArea = area;
        bestFile = file;
      }
    }
    return bestFile;
  }

  TdJson? _stickerFile(TdJson? sticker) {
    final file = sticker?['sticker'];
    return file is TdJson ? file : null;
  }

  TdJson? _animationFile(TdJson? animation) {
    final file = animation?['animation'];
    return file is TdJson ? file : null;
  }

  Future<String?> _downloadFilePath(TdJson? file) async {
    if (file == null) return null;

    final localPath = _localFilePath(file);
    if (localPath != null && File(localPath).existsSync()) return localPath;

    final fileId = file['id'];
    if (fileId is! int) return localPath;

    try {
      final downloaded = await _gateway.invoke({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 16,
        'offset': 0,
        'limit': 0,
        'synchronous': true,
      }, timeout: const Duration(seconds: 60));
      return _localFilePath(downloaded) ?? localPath;
    } catch (_) {
      return localPath;
    }
  }

  String? _localFilePath(TdJson file) {
    final local = file['local'];
    if (local is! TdJson) return null;
    final path = local['path'];
    if (path is String && path.trim().isNotEmpty) return path;
    return null;
  }

  String _captionText(TdJson? content) {
    final caption = (content?['caption'] as TdJson?)?['text'];
    if (caption is String && caption.trim().isNotEmpty) return caption;
    return '';
  }

  String _messagePreview(TdJson? message) {
    final content = message?['content'];
    if (content is! TdJson) return '';
    return switch (content['@type']) {
      'messageText' => (content['text'] as TdJson?)?['text'] as String? ?? '',
      'messagePhoto' => 'Photo',
      'messageAnimation' => 'GIF',
      'messageSticker' => 'Sticker',
      'messageDocument' => 'File',
      'messageVideo' => 'Video',
      'messageVoiceNote' => 'Voice message',
      _ => 'Message',
    };
  }

  String? _codeDeliveryMessage(TdJson? codeInfo) {
    if (codeInfo == null) return null;
    final type =
        _codeTypeLabel(codeInfo['type'] as TdJson?) ?? 'CODE REQUESTED';
    final nextType = _codeTypeLabel(codeInfo['next_type'] as TdJson?);
    final timeout = codeInfo['timeout'];
    final resend = nextType == null || timeout is! int || timeout <= 0
        ? ''
        : ' / $nextType IN ${_formatSeconds(timeout)}';
    return '$type$resend';
  }

  String _authErrorText(Object error) {
    final text = error.toString();
    if (text.contains('PHONE_CODE_INVALID')) return 'WRONG CODE';
    if (text.contains('PHONE_CODE_EXPIRED')) return 'CODE EXPIRED';
    if (text.contains('PHONE_NUMBER_INVALID')) return 'WRONG PHONE NUMBER';
    if (text.contains('PASSWORD_HASH_INVALID')) return 'WRONG PASSWORD';
    if (text.contains('FLOOD_WAIT')) return 'TOO MANY TRIES. WAIT A BIT';
    return text.toUpperCase();
  }

  String? _codeTypeLabel(TdJson? type) {
    return switch (type?['@type']) {
      'authenticationCodeTypeTelegramMessage' => 'CODE SENT TO TELEGRAM',
      'authenticationCodeTypeSms' => 'CODE SENT BY SMS',
      'authenticationCodeTypeCall' => 'CODE SENT BY CALL',
      'authenticationCodeTypeFlashCall' => 'WAITING FOR FLASH CALL',
      'authenticationCodeTypeMissedCall' => 'WAITING FOR MISSED CALL',
      'authenticationCodeTypeFragment' => 'CODE SENT TO FRAGMENT',
      _ => null,
    };
  }

  String _formatSeconds(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = seconds % 60;
    if (minutes == 0) return '${rest}s';
    return '${minutes}m ${rest.toString().padLeft(2, '0')}s';
  }

  bool _isOutgoing(TdJson? message) => message?['is_outgoing'] == true;

  bool _isPinned(Object? positions) {
    if (positions is! List) return false;
    return positions.whereType<TdJson>().any((position) {
      return position['is_pinned'] == true;
    });
  }

  bool _isGroup(Object? type) {
    if (type is! TdJson) return false;
    return switch (type['@type']) {
      'chatTypeBasicGroup' || 'chatTypeSupergroup' => true,
      _ => false,
    };
  }

  bool _isChannel(Object? type) {
    if (type is! TdJson) return false;
    return type['@type'] == 'chatTypeSupergroup' && type['is_channel'] == true;
  }

  String _initials(String? title) {
    final trimmed = title?.trim() ?? '';
    if (trimmed.isEmpty) return 'TG';
    final words = trimmed.split(RegExp(r'\s+'));
    if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
    return '${words[0][0]}${words[1][0]}'.toUpperCase();
  }
}
