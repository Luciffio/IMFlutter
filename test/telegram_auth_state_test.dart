import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im/models/auth_session.dart';
import 'package:im/services/mock_chat_repository.dart';
import 'package:im/services/tdlib_gateway.dart';
import 'package:im/services/telegram_repository.dart';
import 'package:im/widgets/auth_screen.dart';

void main() {
  test('maps every interactive TDLib authorization state', () async {
    final gateway = _FakeTdlibGateway();
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
    );

    await repository.connect();
    expect((await repository.getAuthState()).stage, AuthStage.waitPhone);

    await gateway.emitAuthorizationState({
      '@type': 'authorizationStateWaitEmailAddress',
      'allow_apple_id': false,
      'allow_google_id': false,
    });
    expect((await repository.getAuthState()).stage, AuthStage.waitEmailAddress);

    await gateway.emitAuthorizationState({
      '@type': 'authorizationStateWaitEmailCode',
      'allow_apple_id': false,
      'allow_google_id': false,
      'code_info': {
        '@type': 'emailAddressAuthenticationCodeInfo',
        'email_address_pattern': 'k***@example.com',
        'length': 6,
      },
      'email_address_reset_state': null,
    });
    final emailCode = await repository.getAuthState();
    expect(emailCode.stage, AuthStage.waitEmailCode);
    expect(emailCode.emailAddressPattern, 'k***@example.com');
    expect(emailCode.canResendCode, isTrue);

    await gateway.emitAuthorizationState({
      '@type': 'authorizationStateWaitOtherDeviceConfirmation',
      'link': 'tg://login?token=test',
    });
    final confirmation = await repository.getAuthState();
    expect(confirmation.stage, AuthStage.waitOtherDevice);
    expect(confirmation.otherDeviceLink, 'tg://login?token=test');

    await gateway.emitAuthorizationState({
      '@type': 'authorizationStateWaitRegistration',
      'terms_of_service': {
        '@type': 'termsOfService',
        'text': {
          '@type': 'formattedText',
          'text': 'Telegram terms',
          'entities': <Object>[],
        },
        'min_user_age': 0,
        'show_popup': false,
      },
    });
    final registration = await repository.getAuthState();
    expect(registration.stage, AuthStage.waitRegistration);
    expect(registration.registrationTerms, 'Telegram terms');

    await repository.disconnect();
  });

  test('coalesces concurrent phone number submissions', () async {
    final gateway = _FakeTdlibGateway()..holdPhoneRequest = true;
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
    );

    await repository.connect();
    final first = repository.submitPhoneNumber('+10000000000');
    await Future<void>.delayed(Duration.zero);
    await repository.submitPhoneNumber('+10000000000');

    expect(gateway.phoneRequestCount, 1);
    gateway.completePhoneRequest();
    await first;

    await repository.disconnect();
  });

  test('coalesces duplicate TDLib parameter requests during startup', () async {
    final databaseDirectory = await Directory.systemTemp.createTemp(
      'personagram-tdlib-test-',
    );
    addTearDown(() => databaseDirectory.delete(recursive: true));
    final gateway = _FakeTdlibGateway()
      ..currentAuthorizationState = {
        '@type': 'authorizationStateWaitTdlibParameters',
      }
      ..holdParametersRequest = true;
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: databaseDirectory.path,
    );

    final connect = repository.connect();
    for (
      var attempt = 0;
      attempt < 20 && gateway.parametersRequestCount == 0;
      attempt++
    ) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await gateway.emitAuthorizationState({
      '@type': 'authorizationStateWaitTdlibParameters',
    });

    expect(gateway.parametersRequestCount, 1);
    gateway.completeParametersRequest();
    await connect;

    await repository.disconnect();
  });

  test('resends TDLib parameters after leaving QR authentication', () async {
    final databaseDirectory = await Directory.systemTemp.createTemp(
      'personagram-tdlib-reset-test-',
    );
    addTearDown(() => databaseDirectory.delete(recursive: true));
    final gateway = _FakeTdlibGateway()
      ..currentAuthorizationState = {
        '@type': 'authorizationStateWaitTdlibParameters',
      };
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: databaseDirectory.path,
    );

    await repository.connect();
    expect(gateway.parametersRequestCount, 1);

    gateway.currentAuthorizationState = {
      '@type': 'authorizationStateWaitTdlibParameters',
    };
    await repository.cancelAuthentication();

    expect(gateway.resetClientCount, 1);
    expect(gateway.parametersRequestCount, 2);

    await repository.disconnect();
  });

  testWidgets('renders every extended authorization step', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _AuthScreenRepository(
      const AuthSessionState(stage: AuthStage.waitEmailAddress),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          repository: repository,
          onAuthenticated: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('YOUR EMAIL'), findsOneWidget);

    repository.emit(
      const AuthSessionState(
        stage: AuthStage.waitEmailCode,
        codeDeliveryMessage: 'CODE SENT TO K***@EXAMPLE.COM',
        canResendCode: true,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('EMAIL CODE'), findsNWidgets(2));
    expect(find.byTooltip('Resend code'), findsOneWidget);

    repository.emit(
      const AuthSessionState(
        stage: AuthStage.waitOtherDevice,
        otherDeviceLink: 'tg://login?token=test',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CONFIRM LOGIN'), findsOneWidget);
    expect(find.text('OPEN TG'), findsOneWidget);

    repository.emit(
      const AuthSessionState(
        stage: AuthStage.waitRegistration,
        registrationTerms: 'Telegram terms',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('YOUR NAME'), findsOneWidget);
    expect(find.text('ACCEPT'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await repository.closeAuthStream();
  });

  testWidgets('starts Telegram login from the phone step', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _AuthScreenRepository(
      const AuthSessionState(stage: AuthStage.waitPhone),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: AuthScreen(
          repository: repository,
          onAuthenticated: () {},
          onCancel: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Login with Telegram'));
    await tester.pumpAndSettle();

    expect(repository.telegramLoginRequests, 1);
    expect(find.text('CONFIRM LOGIN'), findsOneWidget);
    expect(find.text('OPEN TG'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await repository.closeAuthStream();
  });
}

class _AuthScreenRepository extends MockChatRepository {
  final _authStates = StreamController<AuthSessionState>.broadcast();
  AuthSessionState state;
  int telegramLoginRequests = 0;

  _AuthScreenRepository(this.state);

  @override
  Stream<AuthSessionState> get authState => _authStates.stream;

  @override
  Future<AuthSessionState> getAuthState() async => state;

  @override
  Future<void> startAuthentication() async {
    _authStates.add(state);
  }

  void emit(AuthSessionState next) {
    state = next;
    _authStates.add(next);
  }

  @override
  Future<void> requestQrCodeAuthentication() async {
    telegramLoginRequests++;
    emit(
      const AuthSessionState(
        stage: AuthStage.waitOtherDevice,
        otherDeviceLink: 'tg://login?token=test',
      ),
    );
  }

  Future<void> closeAuthStream() => _authStates.close();
}

class _FakeTdlibGateway extends TdlibGateway {
  final _updates = StreamController<TdJson>.broadcast();
  TdJson currentAuthorizationState = {
    '@type': 'authorizationStateWaitPhoneNumber',
  };
  bool holdPhoneRequest = false;
  bool holdParametersRequest = false;
  int phoneRequestCount = 0;
  int parametersRequestCount = 0;
  int resetClientCount = 0;
  Completer<TdJson>? _phoneRequest;
  Completer<TdJson>? _parametersRequest;

  @override
  Stream<TdJson> get updates => _updates.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<TdJson> invoke(
    TdJson request, {
    Duration timeout = const Duration(seconds: 35),
  }) async {
    switch (request['@type']) {
      case 'getAuthorizationState':
        return currentAuthorizationState;
      case 'setAuthenticationPhoneNumber':
        phoneRequestCount++;
        if (holdPhoneRequest) {
          _phoneRequest = Completer<TdJson>();
          return _phoneRequest!.future;
        }
        return {'@type': 'ok'};
      case 'setTdlibParameters':
        parametersRequestCount++;
        if (holdParametersRequest) {
          _parametersRequest ??= Completer<TdJson>();
          return _parametersRequest!.future;
        }
        return {'@type': 'ok'};
      default:
        return {'@type': 'ok'};
    }
  }

  Future<void> emitAuthorizationState(TdJson state) async {
    currentAuthorizationState = state;
    _updates.add({
      '@type': 'updateAuthorizationState',
      'authorization_state': state,
    });
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }

  @override
  Future<void> resetClient() async {
    resetClientCount++;
  }

  void completePhoneRequest() {
    _phoneRequest?.complete({'@type': 'ok'});
  }

  void completeParametersRequest() {
    _parametersRequest?.complete({'@type': 'ok'});
  }

  @override
  Future<void> close() async {
    await _updates.close();
  }
}
