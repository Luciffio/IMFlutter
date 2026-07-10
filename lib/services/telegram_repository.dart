import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/auth_session.dart';
import '../models/chat_summary.dart';
import '../models/message.dart';
import 'chat_repository.dart';
import 'tdlib_gateway.dart';

class _SenderProfile {
  final String? avatarPath;
  final String? label;

  const _SenderProfile({this.avatarPath, this.label});
}

class TelegramRepository implements ChatRepository {
  static const _configuredDatabaseSuffix = String.fromEnvironment(
    'TG_DATABASE_SUFFIX',
  );

  final int apiId;
  final String apiHash;
  final TdlibGateway _gateway;
  final String? _databaseDirectoryPath;
  final String databaseSuffix;

  final _messageController = StreamController<Message>.broadcast();
  final _messageUpdateController = StreamController<Message>.broadcast();
  final _typingController = StreamController<ChatTypingUpdate>.broadcast();
  final _chatController = StreamController<List<ChatSummary>>.broadcast();
  final _authController = StreamController<AuthSessionState>.broadcast();

  final _chatsById = <String, ChatSummary>{};
  final _messagesByChat = <String, List<Message>>{};
  final _senderProfilesByKey = <String, _SenderProfile>{};
  final _lastMessageIdByChatId = <String, int>{};
  final _directUserIdByChatId = <String, int>{};
  final _userActivityById = <int, ChatActivity>{};
  final _botUserIds = <int>{};
  final _typingSendersByChat = <String, Set<String>>{};
  final _fileStateById = <int, TdJson>{};
  final _messageRefsByFileId =
      <int, Set<({String chatId, String messageId})>>{};
  int? _myUserId;

  StreamSubscription<TdJson>? _updatesSub;
  AuthSessionState _authState = const AuthSessionState.signedOut();
  var _connected = false;
  var _ready = false;
  var _authRequestInFlight = false;
  Future<void>? _tdlibParametersRequest;
  var _tdlibParametersAccepted = false;
  var _chatCacheLoaded = false;
  Future<void>? _chatRefresh;
  Timer? _chatCacheWriteTimer;
  List<ComposerMediaItem>? _savedStickerItems;
  List<ComposerMediaItem>? _savedGifItems;
  DateTime? _savedStickerItemsAt;
  DateTime? _savedGifItemsAt;
  Future<List<ComposerMediaItem>>? _savedStickerItemsRequest;
  Future<List<ComposerMediaItem>>? _savedGifItemsRequest;

  TelegramRepository({
    required this.apiId,
    required this.apiHash,
    TdlibGateway? gateway,
    String? databaseDirectoryPath,
    String? databaseSuffix,
  }) : _gateway = gateway ?? TdlibGateway(),
       _databaseDirectoryPath = databaseDirectoryPath,
       databaseSuffix = databaseSuffix ?? _configuredDatabaseSuffix;

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

    await _loadChatCache();

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
    await _handleAuthorizationState(
      state['authorization_state'] as TdJson? ?? state,
    );
  }

  @override
  Future<void> disconnect() async {
    _ready = false;
    _connected = false;
    _chatCacheWriteTimer?.cancel();
    final updatesCancel = _updatesSub?.cancel();
    _updatesSub = null;
    final gatewayClose = _gateway.close();
    await _writeChatCache();
    await updatesCancel;
    await gatewayClose;
    await _messageController.close();
    await _messageUpdateController.close();
    await _typingController.close();
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
    await _handleAuthorizationState(
      state['authorization_state'] as TdJson? ?? state,
    );
  }

  @override
  Future<void> submitPhoneNumber(String phoneNumber) async {
    await _invokeAuth({
      '@type': 'setAuthenticationPhoneNumber',
      'phone_number': phoneNumber.trim(),
      'settings': {
        '@type': 'phoneNumberAuthenticationSettings',
        'allow_flash_call': false,
        'allow_missed_call': false,
        'is_current_phone_number': true,
        'has_unknown_phone_number': false,
        'allow_sms_retriever_api': false,
        'firebase_authentication_settings': null,
        'authentication_tokens': const <String>[],
      },
    });
  }

  @override
  Future<void> submitEmailAddress(String emailAddress) async {
    await _invokeAuth({
      '@type': 'setAuthenticationEmailAddress',
      'email_address': emailAddress.trim(),
    });
  }

  @override
  Future<void> submitEmailCode(String code) async {
    await _invokeAuth({
      '@type': 'checkAuthenticationEmailCode',
      'code': {'@type': 'emailAddressAuthenticationCode', 'code': code.trim()},
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
  Future<void> submitRegistration(String firstName, String lastName) async {
    await _invokeAuth({
      '@type': 'registerUser',
      'first_name': firstName.trim(),
      'last_name': lastName.trim(),
      'disable_notification': false,
    });
  }

  @override
  Future<void> resendAuthenticationCode() async {
    await _invokeAuth({'@type': 'resendAuthenticationCode', 'reason': null});
  }

  @override
  Future<void> requestQrCodeAuthentication() async {
    await _invokeAuth({
      '@type': 'requestQrCodeAuthentication',
      'other_user_ids': const <int>[],
    });
  }

  @override
  Future<void> cancelAuthentication() async {
    await _updatesSub?.cancel();
    _updatesSub = null;
    _ready = false;
    _connected = false;
    _authRequestInFlight = false;
    _tdlibParametersRequest = null;
    _tdlibParametersAccepted = false;
    _chatsById.clear();
    _messagesByChat.clear();
    _emitChats(persist: false);
    _setAuthState(
      _authState.copyWith(
        isLoading: true,
        clearError: true,
        clearCodeDelivery: true,
      ),
    );

    await _gateway.resetClient();
    await connect();
  }

  @override
  Future<void> signOut() async {
    await _gateway.invoke({'@type': 'logOut'});
    _ready = false;
    _chatsById.clear();
    _savedStickerItems = null;
    _savedGifItems = null;
    _savedStickerItemsAt = null;
    _savedGifItemsAt = null;
    await _clearChatCache();
    _emitChats(persist: false);
    _setAuthState(const AuthSessionState.signedOut());
  }

  @override
  Future<List<ChatSummary>> getChats() async {
    await connect();
    if (!_ready) return _sortedChats();

    if (_chatsById.isEmpty) {
      await _refreshChatsFromTdlib();
    } else {
      unawaited(_refreshChatsFromTdlib());
    }
    return _sortedChats();
  }

  Future<void> _refreshChatsFromTdlib() {
    final active = _chatRefresh;
    if (active != null) return active;
    final refresh = _performChatRefresh().catchError((_) {
      // Account switches and shutdown can cancel an in-flight TDLib request.
    });
    _chatRefresh = refresh;
    return refresh.whenComplete(() {
      if (identical(_chatRefresh, refresh)) _chatRefresh = null;
    });
  }

  Future<void> _performChatRefresh() async {
    if (!_ready) return;

    final results = await Future.wait([
      _gateway.invoke({
        '@type': 'getChats',
        'chat_list': {'@type': 'chatListMain'},
        'limit': 80,
      }),
      _gateway.invoke({
        '@type': 'getChats',
        'chat_list': {'@type': 'chatListArchive'},
        'limit': 80,
      }),
    ]);
    final ids = <Object?>[
      for (final result in results)
        ...(result['chat_ids'] as List? ?? const []),
    ];
    final visibleIds = ids.whereType<int>().map((id) => id.toString()).toSet();
    final bothListsAreEmpty = results.every(
      (result) => result['total_count'] == 0,
    );
    if (visibleIds.isNotEmpty || bothListsAreEmpty) {
      _chatsById.removeWhere((id, _) => !visibleIds.contains(id));
    }

    final unknownIds = ids
        .whereType<int>()
        .where((id) => !_chatsById.containsKey(id.toString()))
        .toList();
    const batchSize = 12;
    for (var start = 0; start < unknownIds.length; start += batchSize) {
      final end = (start + batchSize).clamp(0, unknownIds.length);
      final chats = await Future.wait([
        for (final id in unknownIds.sublist(start, end))
          _gateway.invoke({'@type': 'getChat', 'chat_id': id}),
      ]);
      for (final chat in chats) {
        await _cacheChat(chat, forceVisible: true);
      }
      _emitChats();
    }

    _emitChats();
  }

  @override
  Future<List<Message>> getMessages(String chatId) async {
    await connect();
    if (!_ready) return List.unmodifiable(_messagesByChat[chatId] ?? const []);

    final id = int.tryParse(chatId);
    if (id == null) return const [];

    unawaited(_openChat(id));
    final rawMessages = await _loadChatHistory(id);
    final messages = await _mapMessageSequence(rawMessages.reversed.toList());
    _messagesByChat[chatId] = messages;
    return List.unmodifiable(messages);
  }

  @override
  Future<List<Message>> getMessagesBefore(
    String chatId,
    String beforeMessageId,
  ) async {
    await connect();
    if (!_ready) return const [];

    final chatIdInt = int.tryParse(chatId);
    final beforeId = int.tryParse(beforeMessageId);
    if (chatIdInt == null || beforeId == null || beforeId <= 0) {
      return const [];
    }

    final rawMessages = await _loadChatHistory(
      chatIdInt,
      fromMessageId: beforeId,
      pageCount: 3,
      maxMessages: 40,
    );
    final older = rawMessages.where((raw) {
      final id = raw['id'];
      return id is int && id < beforeId;
    }).toList();
    final messages = await _mapMessageSequence(older.reversed.toList());

    final current = _messagesByChat[chatId] ?? const <Message>[];
    final knownIds = current.map((message) => message.id).whereType<String>();
    final known = knownIds.toSet();
    final fresh = messages
        .where((message) => message.id == null || !known.contains(message.id))
        .toList();
    _messagesByChat[chatId] = [...fresh, ...current];
    return List.unmodifiable(fresh);
  }

  Future<List<TdJson>> _loadChatHistory(
    int chatId, {
    int fromMessageId = 0,
    int pageCount = 6,
    int maxMessages = 80,
  }) async {
    final byId = <int, TdJson>{};
    var cursorMessageId = fromMessageId;

    for (var page = 0; page < pageCount; page++) {
      final result = await _gateway.invoke({
        '@type': 'getChatHistory',
        'chat_id': chatId,
        'from_message_id': cursorMessageId,
        'offset': 0,
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
      if (oldestId is! int || oldestId == cursorMessageId) break;
      cursorMessageId = oldestId;

      if (byId.length >= maxMessages) break;
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
    final lastMessageId = _lastMessageIdByChatId[chatId];
    if (lastMessageId != null) {
      await _gateway.invoke({
        '@type': 'viewMessages',
        'chat_id': id,
        'message_ids': [lastMessageId],
        'source': null,
        'force_read': true,
      });
    }
    if (_chatsById[chatId]?.isMarkedUnread == true) {
      await setChatMarkedUnread(chatId, false);
    }
    final current = _chatsById[chatId];
    if (current != null && current.unreadCount != 0) {
      _chatsById[chatId] = current.copyWith(unreadCount: 0);
      _emitChats();
    }
  }

  @override
  Future<void> setChatMarkedUnread(String chatId, bool isMarkedUnread) async {
    final id = int.tryParse(chatId);
    if (id == null || !_ready) return;
    await _gateway.invoke({
      '@type': 'toggleChatIsMarkedAsUnread',
      'chat_id': id,
      'is_marked_as_unread': isMarkedUnread,
    });
    final current = _chatsById[chatId];
    if (current != null) {
      _chatsById[chatId] = current.copyWith(isMarkedUnread: isMarkedUnread);
      _emitChats();
    }
  }

  @override
  Future<void> setChatPinned(String chatId, bool isPinned) async {
    final id = int.tryParse(chatId);
    if (id == null || !_ready) return;
    await _gateway.invoke({
      '@type': 'toggleChatIsPinned',
      'chat_list': {
        '@type': _chatsById[chatId]?.isArchived == true
            ? 'chatListArchive'
            : 'chatListMain',
      },
      'chat_id': id,
      'is_pinned': isPinned,
    });
    final current = _chatsById[chatId];
    if (current != null) {
      _chatsById[chatId] = current.copyWith(
        pinnedAt: isPinned ? DateTime.now() : null,
        clearPinnedAt: !isPinned,
      );
      _emitChats();
    }
  }

  @override
  Future<void> setChatArchived(String chatId, bool isArchived) async {
    final id = int.tryParse(chatId);
    if (id == null || !_ready) return;
    await _gateway.invoke({
      '@type': 'addChatToList',
      'chat_id': id,
      'chat_list': {'@type': isArchived ? 'chatListArchive' : 'chatListMain'},
    });
    final current = _chatsById[chatId];
    if (current != null) {
      _chatsById[chatId] = current.copyWith(isArchived: isArchived);
      _emitChats();
    }
  }

  @override
  Future<List<ComposerMediaItem>> getSavedStickers() async {
    await connect();
    if (!_ready) return const [];

    final cached = _freshComposerMediaCache(
      _savedStickerItems,
      _savedStickerItemsAt,
    );
    if (cached != null) return cached;
    final active = _savedStickerItemsRequest;
    if (active != null) return active;

    final request = _loadSavedStickers();
    _savedStickerItemsRequest = request;
    try {
      final items = await request;
      _savedStickerItems = items;
      _savedStickerItemsAt = DateTime.now();
      return items;
    } finally {
      if (identical(_savedStickerItemsRequest, request)) {
        _savedStickerItemsRequest = null;
      }
    }
  }

  Future<List<ComposerMediaItem>> _loadSavedStickers() async {
    final stickers = <TdJson>[];
    for (final request in const [
      {'@type': 'getFavoriteStickers'},
      {'@type': 'getRecentStickers', 'is_attached': false},
    ]) {
      try {
        final result = await _gateway.invoke(
          request,
          timeout: const Duration(seconds: 20),
        );
        stickers.addAll(
          (result['stickers'] as List? ?? const []).whereType<TdJson>(),
        );
      } catch (_) {
        // Some accounts/TDLib builds may not expose every sticker bucket.
      }
    }
    return _mediaItemsFromObjects(
      stickers,
      fileFor: _stickerFile,
      fallbackLabel: 'STICKER',
    );
  }

  @override
  Future<List<ComposerMediaItem>> getSavedGifs() async {
    await connect();
    if (!_ready) return const [];

    final cached = _freshComposerMediaCache(_savedGifItems, _savedGifItemsAt);
    if (cached != null) return cached;
    final active = _savedGifItemsRequest;
    if (active != null) return active;

    final request = _loadSavedGifs();
    _savedGifItemsRequest = request;
    try {
      final items = await request;
      _savedGifItems = items;
      _savedGifItemsAt = DateTime.now();
      return items;
    } finally {
      if (identical(_savedGifItemsRequest, request)) {
        _savedGifItemsRequest = null;
      }
    }
  }

  Future<List<ComposerMediaItem>> _loadSavedGifs() async {
    try {
      final result = await _gateway.invoke({
        '@type': 'getSavedAnimations',
      }, timeout: const Duration(seconds: 20));
      return _mediaItemsFromObjects(
        (result['animations'] as List? ?? const []).whereType<TdJson>(),
        fileFor: _animationFile,
        fallbackLabel: 'GIF',
      );
    } catch (_) {
      return const [];
    }
  }

  List<ComposerMediaItem>? _freshComposerMediaCache(
    List<ComposerMediaItem>? items,
    DateTime? cachedAt,
  ) {
    if (items == null || cachedAt == null) return null;
    if (DateTime.now().difference(cachedAt) > const Duration(minutes: 5)) {
      return null;
    }
    if (items.any((item) => !File(item.path).existsSync())) return null;
    return items;
  }

  Future<List<ComposerMediaItem>> _mediaItemsFromObjects(
    Iterable<TdJson> objects, {
    required TdJson? Function(TdJson object) fileFor,
    required String fallbackLabel,
  }) async {
    final seen = <int>{};
    final items = <ComposerMediaItem>[];
    for (final object in objects) {
      final file = fileFor(object);
      final fileId = file?['id'];
      if (fileId is int && !seen.add(fileId)) continue;
      final path = await _downloadFilePath(file);
      if (path == null || path.isEmpty) continue;
      items.add(ComposerMediaItem(path: path, label: fallbackLabel));
      if (items.length >= 24) break;
    }
    return List.unmodifiable(items);
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

  @override
  Future<List<Message>> sendPhotos(
    String chatId,
    List<String> paths, {
    String caption = '',
  }) async {
    final id = await _readyChatId(chatId);
    if (paths.isEmpty) return const [];
    final resolved = <String>[];
    for (final path in paths.take(10)) {
      resolved.add(await _materializeInputPath(path));
    }
    final contents = <TdJson>[
      for (var index = 0; index < resolved.length; index++)
        _photoInput(resolved[index], index == 0 ? caption : ''),
    ];

    if (contents.length == 1) {
      final raw = await _sendInputMessage(id, contents.single);
      final message = (await _mapMessage(
        raw,
      )).copyWith(imagePath: resolved.single, albumImagePaths: const []);
      _messagesFor(chatId).add(message);
      return [message];
    }

    final result = await _gateway.invoke({
      '@type': 'sendMessageAlbum',
      'chat_id': id,
      'message_thread_id': 0,
      'reply_to': null,
      'options': null,
      'input_message_contents': contents,
    });
    final rawMessages = (result['messages'] as List? ?? const [])
        .whereType<TdJson>()
        .toList();
    final messages = (await _mapMessageSequence(rawMessages)).map((message) {
      if (!message.isImage || message.imagePaths.isNotEmpty) return message;
      return message.copyWith(
        imagePath: resolved.first,
        albumImagePaths: List.unmodifiable(resolved),
      );
    }).toList();
    _messagesFor(chatId).addAll(messages);
    return messages;
  }

  @override
  Future<Message> sendFile(
    String chatId,
    String path, {
    required String name,
    required int size,
    String caption = '',
  }) async {
    final id = await _readyChatId(chatId);
    final inputPath = await _materializeInputPath(path, preferredName: name);
    final raw = await _sendInputMessage(id, {
      '@type': 'inputMessageDocument',
      'document': {'@type': 'inputFileLocal', 'path': inputPath},
      'thumbnail': null,
      'disable_content_type_detection': true,
      'caption': _formattedText(caption),
    });
    final message = (await _mapMessage(raw)).copyWith(filePath: inputPath);
    _messagesFor(chatId).add(message);
    return message;
  }

  @override
  Future<Message> sendGif(
    String chatId,
    String path, {
    String caption = '',
  }) async {
    final id = await _readyChatId(chatId);
    final inputPath = await _materializeInputPath(path);
    final raw = await _sendInputMessage(id, {
      '@type': 'inputMessageAnimation',
      'animation': {'@type': 'inputFileLocal', 'path': inputPath},
      'thumbnail': null,
      'added_sticker_file_ids': const <int>[],
      'duration': 0,
      'width': 0,
      'height': 0,
      'caption': _formattedText(caption),
      'show_caption_above_media': false,
      'has_spoiler': false,
    });
    final message = (await _mapMessage(raw)).copyWith(gifPath: inputPath);
    _messagesFor(chatId).add(message);
    return message;
  }

  @override
  Future<Message> sendSticker(String chatId, String path) async {
    final id = await _readyChatId(chatId);
    final inputPath = await _materializeInputPath(path);
    final raw = await _sendInputMessage(id, {
      '@type': 'inputMessageSticker',
      'sticker': {'@type': 'inputFileLocal', 'path': inputPath},
      'thumbnail': null,
      'width': 512,
      'height': 512,
      'emoji': '',
    });
    final message = (await _mapMessage(raw)).copyWith(stickerPath: inputPath);
    _messagesFor(chatId).add(message);
    return message;
  }

  Future<int> _readyChatId(String chatId) async {
    await connect();
    final id = int.tryParse(chatId);
    if (id == null || !_ready) {
      throw StateError('Telegram chat is not ready');
    }
    return id;
  }

  Future<TdJson> _sendInputMessage(int chatId, TdJson content) {
    return _gateway.invoke({
      '@type': 'sendMessage',
      'chat_id': chatId,
      'message_thread_id': 0,
      'reply_to': null,
      'options': null,
      'reply_markup': null,
      'input_message_content': content,
    }, timeout: const Duration(minutes: 3));
  }

  TdJson _photoInput(String path, String caption) => {
    '@type': 'inputMessagePhoto',
    'photo': {'@type': 'inputFileLocal', 'path': path},
    'thumbnail': null,
    'added_sticker_file_ids': const <int>[],
    'width': 0,
    'height': 0,
    'caption': _formattedText(caption),
    'show_caption_above_media': false,
    'self_destruct_type': null,
    'has_spoiler': false,
  };

  TdJson _formattedText(String text) => {
    '@type': 'formattedText',
    'text': text.trim(),
    'entities': const <Object>[],
  };

  Future<String> _materializeInputPath(
    String path, {
    String? preferredName,
  }) async {
    final supportPath =
        _databaseDirectoryPath ?? (await getApplicationSupportDirectory()).path;
    final outputDir = Directory('$supportPath/outbound_media');
    await outputDir.create(recursive: true);
    final originalName = preferredName?.trim().isNotEmpty == true
        ? preferredName!.trim()
        : path.split(RegExp(r'[\\/]')).last;
    final safeName = originalName.replaceAll(
      RegExp(r'[^A-Za-z0-9._() -]'),
      '_',
    );
    final serial = DateTime.now().microsecondsSinceEpoch;
    final transferDir = Directory('${outputDir.path}/$serial');
    await transferDir.create(recursive: true);
    final output = File('${transferDir.path}/$safeName');

    if (path.startsWith('assets/')) {
      final data = await rootBundle.load(path);
      await output.writeAsBytes(data.buffer.asUint8List(), flush: true);
      return output.path;
    }

    final source = File(path);
    if (!await source.exists()) {
      throw FileSystemException('Selected file is no longer available', path);
    }
    await source.copy(output.path);
    return output.path;
  }

  Future<void> _invokeAuth(TdJson request) async {
    if (_authRequestInFlight) return;

    final pendingAuthorizationState = _authorizationStateType(_authState.stage);
    _authRequestInFlight = true;
    _setAuthState(_authState.copyWith(isLoading: true, clearError: true));
    try {
      await _gateway.invoke(request);
    } catch (error) {
      if (_isConcurrentAuthQuery(error)) {
        final progressed = await _waitForPendingAuthQuery(
          pendingAuthorizationState,
        );
        if (!progressed) {
          _setAuthState(
            _authState.copyWith(
              errorMessage: 'AUTH REQUEST BUSY. WAIT A MOMENT AND TRY AGAIN',
            ),
          );
        }
      } else {
        _setAuthState(_authState.copyWith(errorMessage: _authErrorText(error)));
      }
    } finally {
      _authRequestInFlight = false;
      if (!_authState.isReady) {
        _setAuthState(_authState.copyWith(isLoading: false));
      }
    }
  }

  bool _isConcurrentAuthQuery(Object error) {
    return error.toString().toLowerCase().contains(
      'another authorization query has started',
    );
  }

  String? _authorizationStateType(AuthStage stage) {
    return switch (stage) {
      AuthStage.waitPhone => 'authorizationStateWaitPhoneNumber',
      AuthStage.waitEmailAddress => 'authorizationStateWaitEmailAddress',
      AuthStage.waitEmailCode => 'authorizationStateWaitEmailCode',
      AuthStage.waitCode => 'authorizationStateWaitCode',
      AuthStage.waitOtherDevice =>
        'authorizationStateWaitOtherDeviceConfirmation',
      AuthStage.waitRegistration => 'authorizationStateWaitRegistration',
      AuthStage.waitPassword => 'authorizationStateWaitPassword',
      AuthStage.signedOut || AuthStage.ready => null,
    };
  }

  Future<bool> _waitForPendingAuthQuery(String? pendingStateType) async {
    try {
      for (var attempt = 0; attempt < 8; attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        final state = await _gateway.invoke({'@type': 'getAuthorizationState'});
        final authorizationState =
            state['authorization_state'] as TdJson? ?? state;
        await _handleAuthorizationState(authorizationState);
        if (pendingStateType == null ||
            authorizationState['@type'] != pendingStateType) {
          return true;
        }
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  Future<void> _handleUpdate(TdJson update) async {
    switch (update['@type']) {
      case 'updateAuthorizationState':
        await _handleAuthorizationState(
          update['authorization_state'] as TdJson?,
        );
      case 'updateNewChat':
        await _cacheChat(update['chat'] as TdJson?);
        _emitChats();
      case 'updateChatLastMessage':
        await _refreshChat(update['chat_id']);
      case 'updateChatReadInbox':
      case 'updateChatReadOutbox':
      case 'updateChatUnreadMentionCount':
      case 'updateChatIsMarkedAsUnread':
      case 'updateChatPosition':
        await _refreshChat(update['chat_id']);
      case 'updateUserStatus':
        _handleUserStatusUpdate(update);
      case 'updateUser':
        _handleUserUpdate(update['user'] as TdJson?);
      case 'updateChatAction':
        _handleChatActionUpdate(update);
      case 'updateNewMessage':
        final raw = update['message'];
        if (raw is TdJson) {
          final message = await _mapMessage(raw);
          final wasVisible = _upsertCachedMessage(message);
          if (wasVisible || message.isOutgoing) {
            _messageUpdateController.add(_cachedMessageOrSelf(message));
          } else {
            _messageController.add(message);
          }
          await _refreshChat(raw['chat_id']);
        }
      case 'updateMessageContent':
        await _handleMessageContentUpdate(update);
      case 'updateFile':
        _handleFileUpdate(update['file'] as TdJson?);
    }
  }

  Future<void> _handleMessageContentUpdate(TdJson update) async {
    final rawChatId = update['chat_id'];
    final rawMessageId = update['message_id'];
    final content = update['new_content'];
    if (rawChatId is! int || rawMessageId is! int || content is! TdJson) {
      return;
    }
    final cached = _messagesByChat[rawChatId.toString()]
        ?.where((message) => message.id == rawMessageId.toString())
        .firstOrNull;
    final raw = {
      '@type': 'message',
      'id': rawMessageId,
      'chat_id': rawChatId,
      'is_outgoing': cached?.isOutgoing == true,
      'date': (cached?.createdAt?.millisecondsSinceEpoch ?? 0) ~/ 1000,
      'media_album_id': cached?.mediaAlbumId ?? '0',
      'sender_id': null,
      'content': content,
    };
    final mapped = await _mapMessage(raw);
    final message = cached == null
        ? mapped
        : _mergeMessageContent(cached, mapped);
    if (_upsertCachedMessage(message)) {
      _messageUpdateController.add(_cachedMessageOrSelf(message));
    }
  }

  void _handleFileUpdate(TdJson? file) {
    final fileId = _rememberFileState(file);
    if (fileId == null) return;

    final refs = _messageRefsByFileId[fileId];
    if (refs == null || refs.isEmpty) return;
    for (final ref in refs.toList(growable: false)) {
      final messages = _messagesByChat[ref.chatId];
      if (messages == null) continue;
      final index = messages.indexWhere(
        (message) => message.id == ref.messageId,
      );
      if (index < 0) continue;

      final updated = _messageWithCurrentFileState(messages[index]);
      if (identical(updated, messages[index])) continue;
      messages[index] = updated;
      if (!_messageUpdateController.isClosed) {
        _messageUpdateController.add(updated);
      }
    }
  }

  void _handleUserStatusUpdate(TdJson update) {
    final userId = update['user_id'];
    if (userId is! int) return;
    final activity = _botUserIds.contains(userId)
        ? ChatActivity.offline
        : _activityFromStatus(update['status']);
    _userActivityById[userId] = activity;

    var changed = false;
    for (final entry in _directUserIdByChatId.entries) {
      if (entry.value != userId) continue;
      final chat = _chatsById[entry.key];
      if (chat == null || chat.activity == activity) continue;
      _chatsById[entry.key] = chat.copyWith(activity: activity);
      changed = true;
    }
    if (changed) _emitChats();
  }

  void _handleUserUpdate(TdJson? user) {
    if (user == null || !_isBotUser(user)) return;
    final userId = user['id'];
    if (userId is! int) return;
    _botUserIds.add(userId);
    _userActivityById[userId] = ChatActivity.offline;

    var changed = false;
    for (final entry in _directUserIdByChatId.entries) {
      if (entry.value != userId) continue;
      final chat = _chatsById[entry.key];
      if (chat == null || chat.activity == ChatActivity.offline) continue;
      _chatsById[entry.key] = chat.copyWith(activity: ChatActivity.offline);
      changed = true;
    }
    if (changed) _emitChats();
  }

  void _handleChatActionUpdate(TdJson update) {
    final rawChatId = update['chat_id'];
    if (rawChatId is! int) return;
    final chatId = rawChatId.toString();
    final sender = _senderKey(update['sender_id'] as TdJson?) ?? 'unknown';
    final action = update['action'] as TdJson?;
    final senders = _typingSendersByChat.putIfAbsent(chatId, () => <String>{});
    final wasTyping = senders.isNotEmpty;
    if (action?['@type'] == 'chatActionCancel') {
      senders.remove(sender);
    } else {
      senders.add(sender);
    }
    if (senders.isEmpty) _typingSendersByChat.remove(chatId);
    final isTyping = senders.isNotEmpty;
    if (wasTyping == isTyping || _typingController.isClosed) return;
    _typingController.add(ChatTypingUpdate(chatId: chatId, isTyping: isTyping));
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
        await _ensureTdlibParameters();
      case 'authorizationStateWaitPhoneNumber':
        _setAuthState(
          const AuthSessionState.waitPhone().copyWith(clearCodeDelivery: true),
        );
      case 'authorizationStateWaitEmailAddress':
        _setAuthState(
          _authState.copyWith(
            stage: AuthStage.waitEmailAddress,
            canResendCode: false,
            resendTimeoutSeconds: 0,
            clearError: true,
          ),
        );
      case 'authorizationStateWaitEmailCode':
        final emailCodeInfo = state['code_info'] as TdJson?;
        final emailPattern = emailCodeInfo?['email_address_pattern'] as String?;
        _setAuthState(
          _authState.copyWith(
            stage: AuthStage.waitEmailCode,
            emailAddressPattern: emailPattern,
            codeDeliveryMessage: emailPattern == null
                ? 'CODE SENT TO EMAIL'
                : 'CODE SENT TO $emailPattern',
            canResendCode: true,
            resendTimeoutSeconds: 0,
            clearError: true,
          ),
        );
      case 'authorizationStateWaitCode':
        final codeInfo = state['code_info'] as TdJson?;
        final timeout = codeInfo?['timeout'];
        final codeType = codeInfo?['type'] as TdJson?;
        _setAuthState(
          _authState.copyWith(
            stage: AuthStage.waitCode,
            phoneNumber: codeInfo?['phone_number'] as String?,
            codeDeliveryMessage: _codeDeliveryMessage(codeInfo),
            canResendCode: codeInfo?['next_type'] != null,
            resendTimeoutSeconds: timeout is int ? timeout : 0,
            codeIsNumeric: _isNumericCodeType(codeType),
            clearError: true,
          ),
        );
      case 'authorizationStateWaitOtherDeviceConfirmation':
        _setAuthState(
          _authState.copyWith(
            stage: AuthStage.waitOtherDevice,
            otherDeviceLink: state['link'] as String?,
            canResendCode: false,
            resendTimeoutSeconds: 0,
            clearError: true,
          ),
        );
      case 'authorizationStateWaitRegistration':
        final terms = state['terms_of_service'] as TdJson?;
        final termsText = terms?['text'] as TdJson?;
        _setAuthState(
          _authState.copyWith(
            stage: AuthStage.waitRegistration,
            registrationTerms: termsText?['text'] as String?,
            canResendCode: false,
            resendTimeoutSeconds: 0,
            clearError: true,
          ),
        );
      case 'authorizationStateWaitPassword':
        _setAuthState(
          _authState.copyWith(
            stage: AuthStage.waitPassword,
            canResendCode: false,
            resendTimeoutSeconds: 0,
            clearError: true,
          ),
        );
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
    final configuredPath = _databaseDirectoryPath;
    final baseDir = configuredPath == null
        ? Directory(
            '${(await getApplicationSupportDirectory()).path}/tdlib$databaseSuffix',
          )
        : Directory(configuredPath);
    final filesDir = Directory('${baseDir.path}/files');
    await baseDir.create(recursive: true);
    await filesDir.create(recursive: true);

    final parameters = <String, dynamic>{
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
      'application_version': '0.2.0',
    };
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        await _gateway.invoke(parameters);
        return;
      } catch (error) {
        final databaseIsBusy = error.toString().toLowerCase().contains(
          'already in use',
        );
        if (!databaseIsBusy || attempt == 2) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 500 * (attempt + 1)));
      }
    }
  }

  Future<void> _ensureTdlibParameters() async {
    if (_tdlibParametersAccepted) return;

    final pending = _tdlibParametersRequest;
    if (pending != null) {
      await pending;
      return;
    }

    final request = _sendTdlibParameters();
    _tdlibParametersRequest = request;
    try {
      await request;
      _tdlibParametersAccepted = true;
    } catch (error) {
      _setAuthState(
        _authState.copyWith(
          stage: AuthStage.waitPhone,
          isLoading: false,
          errorMessage: _authErrorText(error),
        ),
      );
    } finally {
      _tdlibParametersRequest = null;
    }
  }

  Future<void> _cacheChat(TdJson? raw, {bool forceVisible = false}) async {
    if (raw == null) return;
    final rawId = raw['id'];
    if (rawId is! int) return;
    if (!forceVisible &&
        !_isInMainChatList(raw['positions']) &&
        !_isInArchiveChatList(raw['positions'])) {
      _chatsById.remove(rawId.toString());
      return;
    }

    final summary = await _mapChat(raw);
    _chatsById[summary.id] = summary;
  }

  Future<ChatSummary> _mapChat(TdJson raw) async {
    final id = raw['id'] as int;
    final lastMessage = raw['last_message'] as TdJson?;
    final lastMessageId = lastMessage?['id'];
    if (lastMessageId is int) {
      _lastMessageIdByChatId[id.toString()] = lastMessageId;
    }
    final lastDate = _dateFromUnix(lastMessage?['date']);
    final isPinned = _isPinned(raw['positions']);
    final isChannel = _isChannel(raw['type']);
    final isSavedMessages = await _isSavedMessagesChat(raw['type']);
    final activity = await _activityForChat(id, raw['type']);
    final photoFile = _chatPhotoFile(raw['photo'] as TdJson?);
    final avatarPath = photoFile == null ? null : _localFilePath(photoFile);
    if (avatarPath == null && photoFile != null) {
      unawaited(_hydrateChatAvatar(id.toString(), photoFile));
    }

    return ChatSummary(
      id: id.toString(),
      title: isSavedMessages
          ? 'Saved Messages'
          : (raw['title'] as String?)?.trim().isNotEmpty == true
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
      avatarLabel: isSavedMessages ? 'SV' : _initials(raw['title'] as String?),
      activity: activity,
      pinnedAt: isPinned ? DateTime.now() : null,
      lastIncomingAt: isChannel || _isOutgoing(lastMessage) ? null : lastDate,
      lastOutgoingAt: isChannel || _isOutgoing(lastMessage) ? lastDate : null,
      unreadCount: raw['unread_count'] as int? ?? 0,
      isMarkedUnread: raw['is_marked_as_unread'] == true,
      isArchived: _isInArchiveChatList(raw['positions']),
      isSavedMessages: isSavedMessages,
    );
  }

  Future<bool> _isSavedMessagesChat(Object? type) async {
    if (type is! TdJson) return false;
    final userId = switch (type['@type']) {
      'chatTypePrivate' || 'chatTypeSecret' => type['user_id'],
      _ => null,
    };
    if (userId is! int) return false;
    final myUserId = await _ownUserId();
    return myUserId != null && userId == myUserId;
  }

  Future<int?> _ownUserId() async {
    final cached = _myUserId;
    if (cached != null) return cached;
    try {
      final user = await _gateway.invoke({
        '@type': 'getMe',
      }, timeout: const Duration(seconds: 10));
      final id = user['id'];
      if (id is int) {
        _myUserId = id;
        return id;
      }
    } catch (_) {
      // Saved Messages detection is cosmetic; never block chat loading on it.
    }
    return null;
  }

  Future<ChatActivity> _activityForChat(int chatId, Object? type) async {
    if (type is! TdJson) return ChatActivity.offline;
    final userId = switch (type['@type']) {
      'chatTypePrivate' || 'chatTypeSecret' => type['user_id'],
      _ => null,
    };
    if (userId is! int) return ChatActivity.offline;
    final chatKey = chatId.toString();
    _directUserIdByChatId[chatKey] = userId;

    final cached = _userActivityById[userId];
    if (cached != null) return cached;
    final cachedChatActivity = _chatsById[chatKey]?.activity;
    if (cachedChatActivity != null) {
      _userActivityById[userId] = cachedChatActivity;
      return cachedChatActivity;
    }
    try {
      final user = await _gateway.invoke({
        '@type': 'getUser',
        'user_id': userId,
      }, timeout: const Duration(seconds: 10));
      if (_isBotUser(user)) {
        _botUserIds.add(userId);
        _userActivityById[userId] = ChatActivity.offline;
        return ChatActivity.offline;
      }
      final activity = _activityFromStatus(user['status']);
      _userActivityById[userId] = activity;
      return activity;
    } catch (_) {
      return ChatActivity.offline;
    }
  }

  ChatActivity _activityFromStatus(Object? status) {
    return status is TdJson && status['@type'] == 'userStatusOnline'
        ? ChatActivity.online
        : ChatActivity.offline;
  }

  bool _isBotUser(TdJson user) {
    final type = user['type'];
    return type is TdJson && type['@type'] == 'userTypeBot';
  }

  Future<void> _hydrateChatAvatar(String chatId, TdJson file) async {
    final path = await _downloadFilePath(file);
    if (path == null) return;

    final current = _chatsById[chatId];
    if (current == null || current.avatarPath == path) return;

    _chatsById[chatId] = current.copyWith(avatarPath: path);
    _emitChats();
  }

  Future<_SenderProfile> _senderProfile(
    TdJson? senderId,
    String? fallbackChatId,
  ) async {
    final key = _senderKey(senderId) ?? 'chat:${fallbackChatId ?? ''}';
    final cached = _senderProfilesByKey[key];
    if (cached != null) return cached;

    var label = fallbackChatId == null
        ? null
        : _chatsById[fallbackChatId]?.avatarLabel;
    TdJson? photoFile;

    try {
      switch (senderId?['@type']) {
        case 'messageSenderUser':
          final userId = senderId?['user_id'];
          if (userId is int) {
            final user = await _gateway.invoke({
              '@type': 'getUser',
              'user_id': userId,
            }, timeout: const Duration(seconds: 10));
            label = _userInitials(user) ?? label;
            photoFile = _userPhotoFile(user['profile_photo'] as TdJson?);
          }
        case 'messageSenderChat':
          final chatId = senderId?['chat_id'];
          if (chatId is int) {
            final chat = await _gateway.invoke({
              '@type': 'getChat',
              'chat_id': chatId,
            }, timeout: const Duration(seconds: 10));
            label = _initials(chat['title'] as String?);
            photoFile = _chatPhotoFile(chat['photo'] as TdJson?);
          }
      }
    } catch (_) {
      // Fall back to the row avatar/label if TDLib cannot resolve the sender.
    }

    final fallbackChat = fallbackChatId == null
        ? null
        : _chatsById[fallbackChatId];
    final avatarPath =
        await _downloadFilePath(photoFile) ?? fallbackChat?.avatarPath;
    final profile = _SenderProfile(
      avatarPath: avatarPath,
      label: label ?? fallbackChat?.avatarLabel,
    );
    _senderProfilesByKey[key] = profile;
    return profile;
  }

  String? _senderKey(TdJson? senderId) {
    return switch (senderId?['@type']) {
      'messageSenderUser' => 'user:${senderId?['user_id']}',
      'messageSenderChat' => 'chat:${senderId?['chat_id']}',
      _ => null,
    };
  }

  Sender _senderFor(TdJson? senderId) {
    final key = _senderKey(senderId) ?? '';
    final bucket = key.hashCode.abs() % 3;
    return switch (bucket) {
      0 => Sender.ann,
      1 => Sender.ryuji,
      _ => Sender.yusuke,
    };
  }

  Future<List<Message>> _mapMessageSequence(List<TdJson> rawMessages) async {
    final mapped = <Message>[];
    for (var index = 0; index < rawMessages.length;) {
      final raw = rawMessages[index];
      final albumId = raw['media_album_id']?.toString();
      if (albumId != null && albumId != '0' && albumId.isNotEmpty) {
        final album = <TdJson>[];
        var cursor = index;
        while (cursor < rawMessages.length &&
            rawMessages[cursor]['media_album_id']?.toString() == albumId) {
          album.add(rawMessages[cursor]);
          cursor++;
        }
        final photos = album
            .where(
              (message) =>
                  (message['content'] as TdJson?)?['@type'] == 'messagePhoto',
            )
            .toList();
        if (photos.length > 1) {
          mapped.add(await _mapPhotoAlbum(photos, albumId));
        } else {
          for (final message in album) {
            mapped.add(await _mapMessage(message));
          }
        }
        index = cursor;
        continue;
      }
      mapped.add(await _mapMessage(raw));
      index++;
    }
    return mapped;
  }

  Future<Message> _mapPhotoAlbum(
    List<TdJson> rawMessages,
    String albumId,
  ) async {
    final base = await _mapMessage(rawMessages.first, hydrateMedia: false);
    final paths = <String>[];
    final files = <TdJson>[];
    for (final raw in rawMessages) {
      final content = raw['content'] as TdJson?;
      final file = _largestPhotoFile(content?['photo'] as TdJson?);
      if (file == null) continue;
      files.add(file);
      _rememberFileState(file);
      final path = _availableLocalFilePath(file);
      if (path != null && path.isNotEmpty) paths.add(path);
    }
    final fileIds = files.map(_fileId).whereType<int>().toList(growable: false);
    final message = Message(
      id: base.id,
      chatId: base.chatId,
      sender: base.sender,
      text: rawMessages
          .map((raw) => _captionText(raw['content'] as TdJson?))
          .firstWhere((caption) => caption.isNotEmpty, orElse: () => ''),
      createdAt: base.createdAt,
      status: base.status,
      imagePath: paths.isEmpty ? base.imagePath : paths.first,
      albumImagePaths: List.unmodifiable(paths),
      mediaFileIds: fileIds,
      mediaProgress: _combinedFileProgress(fileIds),
      mediaAlbumId: albumId,
      mediaKind: MessageKind.image,
      avatarPath: base.avatarPath,
      avatarLabel: base.avatarLabel,
    );
    _trackMessageMedia(message);
    if (paths.length < rawMessages.length) {
      for (final file in files) {
        if (_availableLocalFilePath(file) == null) {
          unawaited(_requestMessageMediaDownload(file));
        }
      }
    }
    return message;
  }

  Future<Message> _mapMessage(TdJson raw, {bool hydrateMedia = true}) async {
    final outgoing = raw['is_outgoing'] == true;
    final chatId = (raw['chat_id'] as int?)?.toString();
    final senderId = raw['sender_id'] as TdJson?;
    final senderProfile = outgoing
        ? const _SenderProfile()
        : await _senderProfile(senderId, chatId);
    final content = raw['content'] as TdJson?;
    final mediaKind = switch (content?['@type']) {
      'messagePhoto' => MessageKind.image,
      'messageDocument' => MessageKind.file,
      'messageAnimation' => MessageKind.gif,
      'messageSticker' => MessageKind.sticker,
      _ => MessageKind.text,
    };
    final mediaFile = _mediaFile(content);
    final mediaFileId = _rememberFileState(mediaFile);
    final localMediaPath = mediaFile == null
        ? null
        : _availableLocalFilePath(mediaFile);
    final imagePath = mediaKind == MessageKind.image ? localMediaPath : null;
    final stickerPath = mediaKind == MessageKind.sticker
        ? localMediaPath
        : null;
    final gifPath = mediaKind == MessageKind.gif ? localMediaPath : null;
    final document = content?['@type'] == 'messageDocument'
        ? (content?['document'] as TdJson?)
        : null;
    final documentFile = document?['document'] as TdJson?;
    final filePath = documentFile == null
        ? null
        : _availableLocalFilePath(documentFile);
    final fileSize = documentFile?['size'] ?? documentFile?['expected_size'];

    final message = Message(
      id: (raw['id'] as int?)?.toString(),
      chatId: chatId,
      sender: outgoing ? Sender.ren : _senderFor(senderId),
      text: mediaKind == MessageKind.text
          ? _messagePreview(raw)
          : _captionText(content),
      createdAt: _dateFromUnix(raw['date']),
      status: outgoing
          ? MessageDeliveryStatus.sent
          : MessageDeliveryStatus.delivered,
      imagePath: imagePath,
      stickerPath: stickerPath,
      gifPath: gifPath,
      filePath: filePath,
      fileName: document?['file_name'] as String?,
      fileSize: fileSize is int ? fileSize : null,
      mediaFileIds: mediaFileId == null ? const [] : [mediaFileId],
      mediaProgress: mediaFileId == null
          ? null
          : _combinedFileProgress([mediaFileId]),
      mediaAlbumId: raw['media_album_id']?.toString(),
      mediaKind: mediaKind,
      avatarPath: senderProfile.avatarPath,
      avatarLabel: senderProfile.label,
    );
    _trackMessageMedia(message);
    if (hydrateMedia && mediaFile != null && localMediaPath == null) {
      unawaited(_requestMessageMediaDownload(mediaFile));
    }
    return message;
  }

  TdJson? _mediaFile(TdJson? content) {
    return switch (content?['@type']) {
      'messagePhoto' => _largestPhotoFile(content?['photo'] as TdJson?),
      'messageSticker' => _stickerFile(content?['sticker'] as TdJson?),
      'messageAnimation' => _animationFile(content?['animation'] as TdJson?),
      'messageDocument' =>
        (content?['document'] as TdJson?)?['document'] as TdJson?,
      _ => null,
    };
  }

  Future<void> _requestMessageMediaDownload(TdJson file) async {
    final fileId = _rememberFileState(file);
    if (fileId == null) return;
    try {
      final current = await _gateway.invoke({
        '@type': 'downloadFile',
        'file_id': fileId,
        'priority': 16,
        'offset': 0,
        'limit': 0,
        'synchronous': false,
      }, timeout: const Duration(seconds: 10));
      _handleFileUpdate(current);
    } catch (_) {
      // TDLib may cancel an individual request while the chat is closing.
      // A later updateFile event or reopening the chat will retry it.
    }
  }

  bool _upsertCachedMessage(Message message) {
    final chatId = message.chatId;
    final messageId = message.id;
    if (chatId == null || messageId == null) return false;
    final messages = _messagesFor(chatId);
    message = _messageWithCurrentFileState(message);
    final index = messages.indexWhere((item) => item.id == messageId);
    if (index < 0) {
      messages.add(message);
      return false;
    }
    messages[index] = _mergeMessageMedia(message, messages[index]);
    return true;
  }

  Message _cachedMessageOrSelf(Message message) {
    final chatId = message.chatId;
    final messageId = message.id;
    if (chatId == null || messageId == null) return message;
    final messages = _messagesByChat[chatId];
    if (messages == null) return message;
    return messages.firstWhere(
      (item) => item.id == messageId,
      orElse: () => message,
    );
  }

  Message _mergeMessageMedia(Message incoming, Message existing) {
    return incoming.copyWith(
      imagePath: incoming.imagePath ?? existing.imagePath,
      stickerPath: incoming.stickerPath ?? existing.stickerPath,
      gifPath: incoming.gifPath ?? existing.gifPath,
      filePath: incoming.filePath ?? existing.filePath,
      albumImagePaths: incoming.albumImagePaths.isEmpty
          ? existing.albumImagePaths
          : incoming.albumImagePaths,
      mediaFileIds: incoming.mediaFileIds.isEmpty
          ? existing.mediaFileIds
          : incoming.mediaFileIds,
      mediaProgress: incoming.mediaProgress ?? existing.mediaProgress,
    );
  }

  Message _mergeMessageContent(Message existing, Message content) {
    return Message(
      id: existing.id,
      chatId: existing.chatId,
      sender: existing.sender,
      text: content.text,
      createdAt: existing.createdAt,
      status: existing.status,
      imagePath: content.imagePath ?? existing.imagePath,
      stickerPath: content.stickerPath ?? existing.stickerPath,
      gifPath: content.gifPath ?? existing.gifPath,
      filePath: content.filePath ?? existing.filePath,
      fileName: content.fileName ?? existing.fileName,
      fileSize: content.fileSize ?? existing.fileSize,
      avatarPath: existing.avatarPath,
      avatarLabel: existing.avatarLabel,
      albumImagePaths: content.albumImagePaths.isEmpty
          ? existing.albumImagePaths
          : content.albumImagePaths,
      mediaFileIds: content.mediaFileIds.isEmpty
          ? existing.mediaFileIds
          : content.mediaFileIds,
      mediaProgress: content.mediaProgress ?? existing.mediaProgress,
      mediaAlbumId: content.mediaAlbumId ?? existing.mediaAlbumId,
      mediaKind: content.mediaKind,
    );
  }

  List<Message> _messagesFor(String chatId) {
    return _messagesByChat.putIfAbsent(chatId, () => <Message>[]);
  }

  List<ChatSummary> _sortedChats() {
    final sorted = _dedupeDirectChats(_chatsById.values).toList();
    sorted.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return List.unmodifiable(sorted);
  }

  Iterable<ChatSummary> _dedupeDirectChats(Iterable<ChatSummary> chats) {
    final unique = <String, ChatSummary>{};
    for (final chat in chats) {
      final key = chat.type == ChatType.direct
          ? 'direct:${chat.title.trim().toLowerCase()}'
          : chat.id;
      final existing = unique[key];
      if (existing == null || chat.updatedAt.isAfter(existing.updatedAt)) {
        unique[key] = chat;
      }
    }
    return unique.values;
  }

  String get _chatCacheKey => databaseSuffix.isEmpty
      ? 'telegram.chat_cache.primary'
      : 'telegram.chat_cache.$databaseSuffix';

  Future<void> _loadChatCache() async {
    if (_chatCacheLoaded) return;
    _chatCacheLoaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_chatCacheKey);
      if (encoded == null || encoded.isEmpty) return;
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return;
      for (final value in decoded.whereType<Map<String, dynamic>>()) {
        final chat = _chatFromCache(value);
        if (chat != null) _chatsById[chat.id] = chat;
      }
      _emitChats(persist: false);
    } catch (_) {
      // A malformed cache must never block TDLib startup.
    }
  }

  ChatSummary? _chatFromCache(TdJson value) {
    final id = value['id'];
    final title = value['title'];
    final updatedAt = value['updated_at'];
    if (id is! String || title is! String || updatedAt is! int) return null;
    final typeName = value['type'] as String?;
    final activityName = value['activity'] as String?;
    final type = ChatType.values
        .where((item) => item.name == typeName)
        .firstOrNull;
    final activity = ChatActivity.values
        .where((item) => item.name == activityName)
        .firstOrNull;
    return ChatSummary(
      id: id,
      title: title,
      type: type ?? ChatType.direct,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      participants: const [],
      lastMessagePreview: value['preview'] as String?,
      avatarPath: value['avatar_path'] as String?,
      avatarLabel: value['avatar_label'] as String?,
      activity: type == ChatType.direct
          ? ChatActivity.offline
          : activity ?? ChatActivity.offline,
      pinnedAt: _dateFromCache(value['pinned_at']),
      lastIncomingAt: _dateFromCache(value['last_incoming_at']),
      lastOutgoingAt: _dateFromCache(value['last_outgoing_at']),
      unreadCount: value['unread_count'] as int? ?? 0,
      isMarkedUnread: value['is_marked_unread'] == true,
      isArchived: value['is_archived'] == true,
      isSavedMessages: value['is_saved_messages'] == true,
    );
  }

  DateTime? _dateFromCache(Object? value) {
    return value is int ? DateTime.fromMillisecondsSinceEpoch(value) : null;
  }

  TdJson _chatToCache(ChatSummary chat) => {
    'id': chat.id,
    'title': chat.title,
    'type': chat.type.name,
    'updated_at': chat.updatedAt.millisecondsSinceEpoch,
    'preview': chat.lastMessagePreview,
    'avatar_path': chat.avatarPath,
    'avatar_label': chat.avatarLabel,
    'activity': chat.activity.name,
    'pinned_at': chat.pinnedAt?.millisecondsSinceEpoch,
    'last_incoming_at': chat.lastIncomingAt?.millisecondsSinceEpoch,
    'last_outgoing_at': chat.lastOutgoingAt?.millisecondsSinceEpoch,
    'unread_count': chat.unreadCount,
    'is_marked_unread': chat.isMarkedUnread,
    'is_archived': chat.isArchived,
    'is_saved_messages': chat.isSavedMessages,
  };

  void _scheduleChatCacheWrite() {
    if (!_chatCacheLoaded) return;
    _chatCacheWriteTimer?.cancel();
    _chatCacheWriteTimer = Timer(
      const Duration(milliseconds: 250),
      () => unawaited(_writeChatCache()),
    );
  }

  Future<void> _writeChatCache() async {
    if (!_chatCacheLoaded) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode([
        for (final chat in _sortedChats()) _chatToCache(chat),
      ]);
      await prefs.setString(_chatCacheKey, encoded);
    } catch (_) {
      // Persistence is an optimization; TDLib remains the source of truth.
    }
  }

  Future<void> _clearChatCache() async {
    _chatCacheWriteTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_chatCacheKey);
    } catch (_) {
      // Logging out must still work if the platform cache is unavailable.
    }
  }

  void _emitChats({bool persist = true}) {
    if (_chatController.isClosed) return;
    _chatController.add(_sortedChats());
    if (persist) _scheduleChatCacheWrite();
  }

  void _setAuthState(AuthSessionState state) {
    final effectiveState = _authRequestInFlight && !state.isReady
        ? state.copyWith(isLoading: true)
        : state;
    _authState = effectiveState;
    if (!_authController.isClosed) _authController.add(effectiveState);
  }

  DateTime? _dateFromUnix(Object? value) {
    if (value is! int || value <= 0) return null;
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }

  TdJson? _chatPhotoFile(TdJson? photo) {
    final small = photo?['small'];
    return small is TdJson ? small : null;
  }

  TdJson? _userPhotoFile(TdJson? photo) {
    final small = photo?['small'];
    return small is TdJson ? small : null;
  }

  int? _fileId(TdJson? file) {
    final value = file?['id'];
    return value is int ? value : null;
  }

  int? _rememberFileState(TdJson? file) {
    final id = _fileId(file);
    if (id == null || file == null) return null;
    _fileStateById[id] = file;
    return id;
  }

  void _trackMessageMedia(Message message) {
    final chatId = message.chatId;
    final messageId = message.id;
    if (chatId == null || messageId == null) return;
    final ref = (chatId: chatId, messageId: messageId);
    for (final fileId in message.mediaFileIds) {
      _messageRefsByFileId.putIfAbsent(fileId, () => {}).add(ref);
    }
  }

  double? _combinedFileProgress(List<int> fileIds) {
    if (fileIds.isEmpty) return null;
    var total = 0.0;
    for (final fileId in fileIds) {
      total += _fileProgress(_fileStateById[fileId]);
    }
    return (total / fileIds.length).clamp(0.0, 1.0);
  }

  double _fileProgress(TdJson? file) {
    if (file == null) return 0;
    final local = file['local'] as TdJson?;
    if (local?['is_downloading_completed'] == true ||
        _availableLocalFilePath(file) != null) {
      return 1;
    }
    final downloaded = local?['downloaded_size'];
    final declaredSize = file['size'];
    final expectedSize = file['expected_size'];
    final size = declaredSize is int && declaredSize > 0
        ? declaredSize
        : expectedSize is int && expectedSize > 0
        ? expectedSize
        : 0;
    if (downloaded is! int || downloaded <= 0 || size <= 0) return 0;
    return (downloaded / size).clamp(0.0, 1.0);
  }

  Message _messageWithCurrentFileState(Message message) {
    final fileIds = message.mediaFileIds;
    if (fileIds.isEmpty) return message;

    final progress = _combinedFileProgress(fileIds);
    final paths = fileIds
        .map(
          (fileId) => _availableLocalFilePath(
            _fileStateById[fileId] ?? const <String, dynamic>{},
          ),
        )
        .whereType<String>()
        .toList(growable: false);

    switch (message.kind) {
      case MessageKind.image:
        if (fileIds.length > 1) {
          if (_samePaths(message.albumImagePaths, paths) &&
              message.mediaProgress == progress) {
            return message;
          }
          return message.copyWith(
            imagePath: paths.isEmpty ? null : paths.first,
            albumImagePaths: List.unmodifiable(paths),
            mediaProgress: progress,
          );
        }
        final path = paths.firstOrNull;
        if (message.imagePath == path && message.mediaProgress == progress) {
          return message;
        }
        return message.copyWith(imagePath: path, mediaProgress: progress);
      case MessageKind.file:
        final path = paths.firstOrNull;
        if (message.filePath == path && message.mediaProgress == progress) {
          return message;
        }
        return message.copyWith(filePath: path, mediaProgress: progress);
      case MessageKind.gif:
        final path = paths.firstOrNull;
        if (message.gifPath == path && message.mediaProgress == progress) {
          return message;
        }
        return message.copyWith(gifPath: path, mediaProgress: progress);
      case MessageKind.sticker:
        final path = paths.firstOrNull;
        if (message.stickerPath == path && message.mediaProgress == progress) {
          return message;
        }
        return message.copyWith(stickerPath: path, mediaProgress: progress);
      case MessageKind.text:
        return message;
    }
  }

  bool _samePaths(List<String> first, List<String> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
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
    _rememberFileState(file);

    final localPath = _localFilePath(file);
    final availablePath = _availableLocalFilePath(file);
    if (availablePath != null) return availablePath;

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
      _rememberFileState(downloaded);
      return _availableLocalFilePath(downloaded) ??
          _localFilePath(downloaded) ??
          localPath;
    } catch (_) {
      return availablePath;
    }
  }

  String? _availableLocalFilePath(TdJson file) {
    final path = _localFilePath(file);
    if (path == null || path.isEmpty) return null;
    return File(path).existsSync() ? path : null;
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
    final normalized = text.toLowerCase();
    if (normalized.contains("can't lock file") ||
        normalized.contains('already in use')) {
      return 'TELEGRAM STORAGE IS BUSY. REOPEN THE APP';
    }
    if (text.contains('PHONE_CODE_INVALID')) return 'WRONG CODE';
    if (text.contains('PHONE_CODE_EXPIRED')) return 'CODE EXPIRED';
    if (text.contains('PHONE_NUMBER_INVALID')) return 'WRONG PHONE NUMBER';
    if (text.contains('PHONE_NUMBER_BANNED')) return 'PHONE NUMBER BANNED';
    if (text.contains('EMAIL_ADDRESS_INVALID')) return 'WRONG EMAIL ADDRESS';
    if (text.contains('EMAIL_CODE_INVALID')) return 'WRONG EMAIL CODE';
    if (text.contains('EMAIL_CODE_EXPIRED')) return 'EMAIL CODE EXPIRED';
    if (text.contains('FIRSTNAME_INVALID')) return 'WRONG FIRST NAME';
    if (text.contains('RESEND_CODE_UNAVAILABLE')) {
      return 'RESEND IS NOT AVAILABLE YET';
    }
    if (text.contains('API_ID_PUBLISHED_FLOOD')) {
      return 'TELEGRAM BLOCKED THIS API ID';
    }
    if (text.contains('PASSWORD_HASH_INVALID')) return 'WRONG PASSWORD';
    if (text.contains('FLOOD_WAIT')) return 'TOO MANY TRIES. WAIT A BIT';
    return text.toUpperCase();
  }

  String? _codeTypeLabel(TdJson? type) {
    return switch (type?['@type']) {
      'authenticationCodeTypeTelegramMessage' => 'CODE SENT TO TELEGRAM',
      'authenticationCodeTypeSms' => 'CODE SENT BY SMS',
      'authenticationCodeTypeSmsWord' => 'SMS WORD SENT',
      'authenticationCodeTypeSmsPhrase' => 'SMS PHRASE SENT',
      'authenticationCodeTypeCall' => 'CODE SENT BY CALL',
      'authenticationCodeTypeFlashCall' => 'WAITING FOR FLASH CALL',
      'authenticationCodeTypeMissedCall' => 'WAITING FOR MISSED CALL',
      'authenticationCodeTypeFragment' => 'CODE SENT TO FRAGMENT',
      'authenticationCodeTypeFirebaseAndroid' =>
        'SMS NEEDS OFFICIAL APP / USE TELEGRAM LOGIN',
      'authenticationCodeTypeFirebaseIos' =>
        'SMS NEEDS OFFICIAL APP / USE TELEGRAM LOGIN',
      _ => null,
    };
  }

  bool _isNumericCodeType(TdJson? type) {
    return switch (type?['@type']) {
      'authenticationCodeTypeSmsWord' ||
      'authenticationCodeTypeSmsPhrase' => false,
      _ => true,
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

  bool _isInMainChatList(Object? positions) {
    if (positions is! List) return false;
    return positions.whereType<TdJson>().any((position) {
      final list = position['list'];
      return list is TdJson && list['@type'] == 'chatListMain';
    });
  }

  bool _isInArchiveChatList(Object? positions) {
    if (positions is! List) return false;
    return positions.whereType<TdJson>().any((position) {
      final list = position['list'];
      return list is TdJson && list['@type'] == 'chatListArchive';
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

  String? _userInitials(TdJson user) {
    final firstName = (user['first_name'] as String?)?.trim() ?? '';
    final lastName = (user['last_name'] as String?)?.trim() ?? '';
    final username = (user['username'] as String?)?.trim() ?? '';

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (firstName.isNotEmpty) return firstName.substring(0, 1).toUpperCase();
    if (lastName.isNotEmpty) return lastName.substring(0, 1).toUpperCase();
    if (username.isNotEmpty) return username.substring(0, 1).toUpperCase();
    return null;
  }
}
