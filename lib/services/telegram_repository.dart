import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

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
  static const _databaseSuffix = String.fromEnvironment('TG_DATABASE_SUFFIX');

  final int apiId;
  final String apiHash;
  final TdlibGateway _gateway;
  final String? _databaseDirectoryPath;

  final _messageController = StreamController<Message>.broadcast();
  final _messageUpdateController = StreamController<Message>.broadcast();
  final _chatController = StreamController<List<ChatSummary>>.broadcast();
  final _authController = StreamController<AuthSessionState>.broadcast();

  final _chatsById = <String, ChatSummary>{};
  final _messagesByChat = <String, List<Message>>{};
  final _senderProfilesByKey = <String, _SenderProfile>{};

  StreamSubscription<TdJson>? _updatesSub;
  AuthSessionState _authState = const AuthSessionState.signedOut();
  var _connected = false;
  var _ready = false;
  var _authRequestInFlight = false;
  Future<void>? _tdlibParametersRequest;
  var _tdlibParametersAccepted = false;

  TelegramRepository({
    required this.apiId,
    required this.apiHash,
    TdlibGateway? gateway,
    String? databaseDirectoryPath,
  }) : _gateway = gateway ?? TdlibGateway(),
       _databaseDirectoryPath = databaseDirectoryPath;

  @override
  Stream<Message> get incomingMessages => _messageController.stream;

  @override
  Stream<Message> get messageUpdates => _messageUpdateController.stream;

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
    await _handleAuthorizationState(
      state['authorization_state'] as TdJson? ?? state,
    );
  }

  @override
  Future<void> disconnect() async {
    await _updatesSub?.cancel();
    await _gateway.close();
    await _messageController.close();
    await _messageUpdateController.close();
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
    _authRequestInFlight = false;
    _tdlibParametersRequest = null;
    _tdlibParametersAccepted = false;
    _chatsById.clear();
    _messagesByChat.clear();
    _emitChats();
    _setAuthState(
      _authState.copyWith(
        isLoading: true,
        clearError: true,
        clearCodeDelivery: true,
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await _gateway.resetClient();
    await connect();
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
      'chat_list': {'@type': 'chatListMain'},
      'limit': 80,
    });

    final ids = (result['chat_ids'] as List? ?? const []);
    final visibleIds = ids.whereType<int>().map((id) => id.toString()).toSet();
    _chatsById.removeWhere((id, _) => !visibleIds.contains(id));

    for (final id in ids.whereType<int>()) {
      final chat = await _gateway.invoke({'@type': 'getChat', 'chat_id': id});
      await _cacheChat(chat, forceVisible: true);
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
      final message = await _mapMessage(raw);
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
    final messages = await _mapMessageSequence(rawMessages);
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
    final inputPath = await _materializeInputPath(path);
    final raw = await _sendInputMessage(id, {
      '@type': 'inputMessageDocument',
      'document': {'@type': 'inputFileLocal', 'path': inputPath},
      'thumbnail': null,
      'disable_content_type_detection': true,
      'caption': _formattedText(caption),
    });
    final message = await _mapMessage(raw);
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
    final message = await _mapMessage(raw);
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
    final message = await _mapMessage(raw);
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

  Future<String> _materializeInputPath(String path) async {
    if (!path.startsWith('assets/')) return path;

    final data = await rootBundle.load(path);
    final supportDir = await getApplicationSupportDirectory();
    final outputDir = Directory('${supportDir.path}/outbound_media');
    await outputDir.create(recursive: true);
    final fileName = path.split('/').last;
    final output = File('${outputDir.path}/$fileName');
    await output.writeAsBytes(data.buffer.asUint8List(), flush: true);
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
            '${(await getApplicationSupportDirectory()).path}/tdlib$_databaseSuffix',
          )
        : Directory(configuredPath);
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
      'application_version': '0.2.0',
    });
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
    if (!forceVisible && !_isInMainChatList(raw['positions'])) {
      _chatsById.remove(rawId.toString());
      return;
    }

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
      lastIncomingAt: isChannel || _isOutgoing(lastMessage) ? null : lastDate,
      lastOutgoingAt: isChannel || _isOutgoing(lastMessage) ? lastDate : null,
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
    for (final raw in rawMessages) {
      final content = raw['content'] as TdJson?;
      final file = _largestPhotoFile(content?['photo'] as TdJson?);
      final path = file == null ? null : _localFilePath(file);
      if (path != null && path.isNotEmpty) paths.add(path);
    }
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
      mediaAlbumId: albumId,
      mediaKind: MessageKind.image,
      avatarPath: base.avatarPath,
      avatarLabel: base.avatarLabel,
    );
    if (paths.length < rawMessages.length) {
      unawaited(_hydratePhotoAlbum(rawMessages, message));
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
    final localMediaPath = mediaFile == null ? null : _localFilePath(mediaFile);
    final imagePath = mediaKind == MessageKind.image ? localMediaPath : null;
    final stickerPath = mediaKind == MessageKind.sticker
        ? localMediaPath
        : null;
    final gifPath = mediaKind == MessageKind.gif ? localMediaPath : null;
    final document = content?['@type'] == 'messageDocument'
        ? (content?['document'] as TdJson?)
        : null;
    final documentFile = document?['document'] as TdJson?;
    final filePath = documentFile == null ? null : _localFilePath(documentFile);
    final fileSize = documentFile?['size'] ?? documentFile?['expected_size'];

    final message = Message(
      id: (raw['id'] as int?)?.toString(),
      chatId: chatId,
      sender: outgoing ? Sender.ren : _senderFor(senderId),
      text:
          imagePath == null &&
              stickerPath == null &&
              gifPath == null &&
              document == null
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
      mediaAlbumId: raw['media_album_id']?.toString(),
      mediaKind: mediaKind,
      avatarPath: senderProfile.avatarPath,
      avatarLabel: senderProfile.label,
    );
    if (hydrateMedia && mediaFile != null && localMediaPath == null) {
      unawaited(_hydrateMessageMedia(mediaFile, message));
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

  Future<void> _hydrateMessageMedia(TdJson file, Message message) async {
    final path = await _downloadFilePath(file);
    if (path == null || path.isEmpty) return;
    final updated = switch (message.kind) {
      MessageKind.image => message.copyWith(imagePath: path),
      MessageKind.file => message.copyWith(filePath: path),
      MessageKind.gif => message.copyWith(gifPath: path),
      MessageKind.sticker => message.copyWith(stickerPath: path),
      MessageKind.text => message,
    };
    _replaceCachedMessage(updated);
    if (!_messageUpdateController.isClosed) {
      _messageUpdateController.add(updated);
    }
  }

  Future<void> _hydratePhotoAlbum(
    List<TdJson> rawMessages,
    Message message,
  ) async {
    final paths = <String>[];
    for (final raw in rawMessages) {
      final content = raw['content'] as TdJson?;
      final path = await _downloadFilePath(
        _largestPhotoFile(content?['photo'] as TdJson?),
      );
      if (path != null && path.isNotEmpty) paths.add(path);
    }
    if (paths.isEmpty) return;
    final updated = message.copyWith(
      imagePath: paths.first,
      albumImagePaths: List.unmodifiable(paths),
    );
    _replaceCachedMessage(updated);
    if (!_messageUpdateController.isClosed) {
      _messageUpdateController.add(updated);
    }
  }

  void _replaceCachedMessage(Message updated) {
    final chatId = updated.chatId;
    final messageId = updated.id;
    if (chatId == null || messageId == null) return;
    final messages = _messagesByChat[chatId];
    if (messages == null) return;
    final index = messages.indexWhere((message) => message.id == messageId);
    if (index >= 0) messages[index] = updated;
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

  void _emitChats() {
    if (!_chatController.isClosed) _chatController.add(_sortedChats());
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
