import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im/models/chat_summary.dart';
import 'package:im/services/tdlib_gateway.dart';
import 'package:im/services/mock_chat_repository.dart';
import 'package:im/services/telegram_repository.dart';
import 'package:im/widgets/background_particles.dart';
import 'package:im/widgets/chat_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('HOLD represents a manual unread mark and takes priority over NEW', () {
    final chat = ChatSummary(
      id: '42',
      title: 'Test chat',
      type: ChatType.direct,
      updatedAt: DateTime(2026),
      participants: const [],
      unreadCount: 2,
    );

    expect(chat.isNew, isTrue);
    expect(chat.shouldShowHoldBadge, isFalse);

    final held = chat.copyWith(isMarkedUnread: true);
    expect(held.isNew, isFalse);
    expect(held.isUnread, isTrue);
    expect(held.shouldShowHoldBadge, isTrue);
  });

  test('maps live chat state and sends unread and pin commands', () async {
    final directory = await Directory.systemTemp.createTemp(
      'personagram-chat-state-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final gateway = _ChatStateGateway();
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: directory.path,
    );
    addTearDown(repository.disconnect);

    await repository.connect();
    final chats = await repository.getChats();
    expect(chats.single.unreadCount, 2);
    expect(chats.single.isNew, isTrue);
    expect(chats.single.isActive, isTrue);

    await repository.setChatMarkedUnread('42', true);
    await repository.setChatPinned('42', true);

    expect(
      gateway.requests,
      contains(containsPair('@type', 'toggleChatIsMarkedAsUnread')),
    );
    expect(
      gateway.requests,
      contains(containsPair('@type', 'toggleChatIsPinned')),
    );
    final updated = await repository.getChats();
    expect(updated.single.isMarkedUnread, isTrue);
    expect(updated.single.isPinned, isTrue);
  });

  test('emits typing changes from TDLib chat actions', () async {
    final directory = await Directory.systemTemp.createTemp(
      'personagram-typing-state-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final gateway = _ChatStateGateway();
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: directory.path,
    );
    addTearDown(repository.disconnect);
    await repository.connect();

    final typing = repository.typingUpdates.first;
    gateway.emit({
      '@type': 'updateChatAction',
      'chat_id': 42,
      'sender_id': {'@type': 'messageSenderUser', 'user_id': 7},
      'action': {'@type': 'chatActionTyping'},
    });

    expect((await typing).isTyping, isTrue);
  });

  test('never exposes Telegram bots as online', () async {
    final directory = await Directory.systemTemp.createTemp(
      'personagram-bot-presence-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final gateway = _ChatStateGateway()..isBot = true;
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: directory.path,
    );
    addTearDown(repository.disconnect);

    await repository.connect();
    final chats = await repository.getChats();
    expect(chats.single.isActive, isFalse);

    gateway.emit({
      '@type': 'updateUserStatus',
      'user_id': 7,
      'status': {'@type': 'userStatusOnline', 'expires': 2000000000},
    });
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect((await repository.getChats()).single.isActive, isFalse);
  });

  test('restores cached chats without requesting every chat again', () async {
    final firstDirectory = await Directory.systemTemp.createTemp(
      'personagram-chat-cache-first-',
    );
    final secondDirectory = await Directory.systemTemp.createTemp(
      'personagram-chat-cache-second-',
    );
    addTearDown(() => firstDirectory.delete(recursive: true));
    addTearDown(() => secondDirectory.delete(recursive: true));

    final firstGateway = _ChatStateGateway();
    final firstRepository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: firstGateway,
      databaseDirectoryPath: firstDirectory.path,
    );
    await firstRepository.connect();
    expect(await firstRepository.getChats(), hasLength(1));
    expect(
      firstGateway.requests.where((request) => request['@type'] == 'getChat'),
      isNotEmpty,
    );
    await firstRepository.disconnect();

    final secondGateway = _ChatStateGateway();
    final secondRepository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: secondGateway,
      databaseDirectoryPath: secondDirectory.path,
    );
    addTearDown(secondRepository.disconnect);
    await secondRepository.connect();

    final cachedChats = await secondRepository.getChats();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(cachedChats.single.title, 'Online user');
    expect(
      secondGateway.requests.where((request) => request['@type'] == 'getChat'),
      isEmpty,
    );
  });

  testWidgets('opens account actions from a profile long press', (
    tester,
  ) async {
    final repository = MockChatRepository();
    await repository.connect();

    await tester.pumpWidget(
      MaterialApp(
        home: ChatListScreen(
          repository: repository,
          accountSlots: const [0, 1],
          activeAccountSlot: 0,
          particleMode: PersonaParticleMode.none,
          particleSeason: PersonaSeason.none,
          transitionAnimationsEnabled: false,
          onParticleModeChanged: (_) {},
          onTransitionAnimationsChanged: (_) {},
          onOpenChat: (_) {},
          onOpenAuth: () {},
          onSwitchAccount: (_) async {},
          onAddAccount: () async {},
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    await tester.longPress(find.byIcon(Icons.person));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ACCOUNTS'), findsOneWidget);
    expect(find.text('ACCOUNT 1 / ACTIVE'), findsOneWidget);
    expect(find.text('ACCOUNT 2'), findsOneWidget);
    expect(find.text('ADD ACCOUNT'), findsOneWidget);
    expect(find.text('LOG OUT'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await repository.disconnect();
  });
}

class _ChatStateGateway extends TdlibGateway {
  final _updates = StreamController<TdJson>.broadcast();
  final requests = <TdJson>[];
  bool isMarkedUnread = false;
  bool isPinned = false;
  bool isBot = false;

  @override
  Stream<TdJson> get updates => _updates.stream;

  @override
  Future<void> initialize() async {}

  void emit(TdJson update) => _updates.add(update);

  @override
  Future<TdJson> invoke(
    TdJson request, {
    Duration timeout = const Duration(seconds: 35),
  }) async {
    requests.add(request);
    if (request['@type'] == 'toggleChatIsMarkedAsUnread') {
      isMarkedUnread = request['is_marked_as_unread'] == true;
      return {'@type': 'ok'};
    }
    if (request['@type'] == 'toggleChatIsPinned') {
      isPinned = request['is_pinned'] == true;
      return {'@type': 'ok'};
    }
    return switch (request['@type']) {
      'getAuthorizationState' => {'@type': 'authorizationStateReady'},
      'getChats' => {
        '@type': 'chats',
        'chat_ids': <int>[42],
      },
      'getChat' => _chat(),
      'getUser' => {
        '@type': 'user',
        'id': 7,
        'first_name': 'Online',
        'last_name': 'User',
        'type': {'@type': isBot ? 'userTypeBot' : 'userTypeRegular'},
        'status': {'@type': 'userStatusOnline', 'expires': 2000000000},
      },
      _ => {'@type': 'ok'},
    };
  }

  TdJson _chat() => {
    '@type': 'chat',
    'id': 42,
    'title': 'Online user',
    'type': {'@type': 'chatTypePrivate', 'user_id': 7},
    'photo': null,
    'positions': [
      {
        '@type': 'chatPosition',
        'list': {'@type': 'chatListMain'},
        'order': '100',
        'is_pinned': isPinned,
      },
    ],
    'last_message': {
      '@type': 'message',
      'id': 99,
      'date': 1783270800,
      'is_outgoing': false,
      'content': {
        '@type': 'messageText',
        'text': {'@type': 'formattedText', 'text': 'Hello', 'entities': []},
      },
    },
    'unread_count': 2,
    'is_marked_as_unread': isMarkedUnread,
  };

  @override
  Future<void> close() async {
    await _updates.close();
  }
}
