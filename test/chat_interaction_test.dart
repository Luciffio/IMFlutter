import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:im/main.dart';
import 'package:im/models/chat_summary.dart';
import 'package:im/services/mock_chat_repository.dart';
import 'package:im/widgets/background_particles.dart';
import 'package:im/widgets/input_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('send button keeps a 48 dp touch target', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: InputBar(onSend: (_) {}),
          ),
        ),
      ),
    );

    final sendButton = find.bySemanticsLabel('Send message');
    expect(sendButton, findsOneWidget);
    expect(tester.getSize(sendButton), const Size(48, 48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge swipe closes a chat', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = MockChatRepository();
    await repository.connect();
    addTearDown(repository.disconnect);
    final chat = ChatSummary(
      id: 'edge-swipe-chat',
      title: 'Edge swipe',
      type: ChatType.direct,
      updatedAt: DateTime(2026, 7, 7),
      participants: const [],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatScreen(
                  chat: chat,
                  repository: repository,
                  particleSeason: PersonaSeason.none,
                ),
              ),
            ),
            child: const Text('Open chat'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open chat'));
    await tester.pumpAndSettle();
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    expect(navigator.canPop(), isTrue);

    final edgeDetector = find.byKey(const ValueKey('chat_edge_back'));
    expect(edgeDetector, findsOneWidget);
    final detectorRect = tester.getRect(edgeDetector);
    final gesture = await tester.startGesture(
      Offset(detectorRect.left + 118, detectorRect.center.dy),
    );
    await gesture.moveBy(const Offset(52, 34));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 500));

    expect(navigator.canPop(), isFalse);
    expect(tester.takeException(), isNull);
  });
}
