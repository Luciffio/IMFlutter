import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:im/models/message.dart';
import 'package:im/services/tdlib_gateway.dart';
import 'package:im/services/telegram_repository.dart';
import 'package:im/widgets/image_bubble.dart';

void main() {
  test(
    'sends a photo album with one caption and maps it as one message',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'personagram-media-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final first = File('${directory.path}/first.jpg')
        ..writeAsStringSync('one');
      final second = File('${directory.path}/second.jpg')
        ..writeAsStringSync('two');
      final gateway = _MediaGateway();
      final repository = TelegramRepository(
        apiId: 1,
        apiHash: 'hash',
        gateway: gateway,
        databaseDirectoryPath: directory.path,
      );

      await repository.connect();
      final messages = await repository.sendPhotos('42', [
        first.path,
        second.path,
      ], caption: 'Album caption');

      final request = gateway.requests.lastWhere(
        (request) => request['@type'] == 'sendMessageAlbum',
      );
      final contents = (request['input_message_contents'] as List)
          .whereType<TdJson>()
          .toList();
      expect(contents, hasLength(2));
      expect(contents.first['@type'], 'inputMessagePhoto');
      expect((contents.first['caption'] as TdJson)['text'], 'Album caption');
      expect((contents.last['caption'] as TdJson)['text'], '');
      expect(messages, hasLength(1));
      expect(messages.single.imagePaths, hasLength(2));
      expect(messages.single.text, 'Album caption');

      await repository.disconnect();
    },
  );

  test('uses native TDLib content types for file, GIF and sticker', () async {
    final directory = await Directory.systemTemp.createTemp(
      'personagram-media-types-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/sample.bin')
      ..writeAsStringSync('payload');
    final gateway = _MediaGateway();
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: directory.path,
    );

    await repository.connect();
    await repository.sendFile(
      '42',
      file.path,
      name: 'sample.bin',
      size: file.lengthSync(),
      caption: 'Document caption',
    );
    await repository.sendGif('42', file.path, caption: 'GIF caption');
    await repository.sendSticker('42', file.path);

    final types = gateway.requests
        .where((request) => request['@type'] == 'sendMessage')
        .map((request) => (request['input_message_content'] as TdJson)['@type'])
        .toList();
    expect(
      types,
      containsAll([
        'inputMessageDocument',
        'inputMessageAnimation',
        'inputMessageSticker',
      ]),
    );
    final documentRequest = gateway.requests.firstWhere((request) {
      if (request['@type'] != 'sendMessage') return false;
      final content = request['input_message_content'] as TdJson;
      return content['@type'] == 'inputMessageDocument';
    });
    final documentContent = documentRequest['input_message_content'] as TdJson;
    final document = documentContent['document'] as TdJson;
    final outboundPath = document['path'] as String;
    expect(outboundPath, isNot(file.path));
    expect(File(outboundPath).existsSync(), isTrue);
    expect(File(outboundPath).readAsStringSync(), 'payload');
    expect(outboundPath, endsWith('sample.bin'));
    expect(outboundPath.split(RegExp(r'[\\/]')).last, 'sample.bin');

    await repository.disconnect();
  });

  test('rejects a file that disappeared before TDLib can read it', () async {
    final directory = await Directory.systemTemp.createTemp(
      'personagram-missing-media-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final gateway = _MediaGateway();
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: directory.path,
    );

    await repository.connect();
    await expectLater(
      repository.sendFile(
        '42',
        '${directory.path}/missing.bin',
        name: 'missing.bin',
        size: 0,
      ),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      gateway.requests.where((request) => request['@type'] == 'sendMessage'),
      isEmpty,
    );

    await repository.disconnect();
  });

  test('maps live TDLib download progress and completed media', () async {
    final directory = await Directory.systemTemp.createTemp(
      'personagram-download-progress-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final pendingFile = _remoteFile(501, size: 100);
    final gateway = _MediaGateway(
      historyMessage: {
        '@type': 'message',
        'id': 900,
        'chat_id': 42,
        'is_outgoing': false,
        'date': 1,
        'media_album_id': '0',
        'sender_id': {'@type': 'messageSenderUser', 'user_id': 7},
        'content': {
          '@type': 'messagePhoto',
          'photo': {
            '@type': 'photo',
            'sizes': [
              {
                '@type': 'photoSize',
                'width': 100,
                'height': 100,
                'photo': pendingFile,
              },
            ],
          },
          'caption': _formattedText(''),
        },
      },
      downloadFileResponse: pendingFile,
    );
    final repository = TelegramRepository(
      apiId: 1,
      apiHash: 'hash',
      gateway: gateway,
      databaseDirectoryPath: directory.path,
    );

    await repository.connect();
    final messages = await repository.getMessages('42');
    expect(messages, hasLength(1));
    expect(messages.single.mediaProgress, 0);
    expect(messages.single.imagePath, isNull);
    await Future<void>.delayed(Duration.zero);
    final downloadRequest = gateway.requests.lastWhere(
      (request) => request['@type'] == 'downloadFile',
    );
    expect(downloadRequest['synchronous'], isFalse);

    final halfway = repository.messageUpdates.firstWhere(
      (message) => message.id == '900' && message.mediaProgress == 0.5,
    );
    gateway.emitUpdate({
      '@type': 'updateFile',
      'file': _remoteFile(501, size: 100, downloadedSize: 50),
    });
    expect((await halfway).imagePath, isNull);

    final downloaded = File('${directory.path}/photo.jpg')
      ..writeAsStringSync('image');
    final completed = repository.messageUpdates.firstWhere(
      (message) => message.id == '900' && message.mediaProgress == 1,
    );
    gateway.emitUpdate({
      '@type': 'updateFile',
      'file': _remoteFile(
        501,
        size: 100,
        downloadedSize: 100,
        path: downloaded.path,
        isCompleted: true,
      ),
    });
    final completedMessage = await completed;
    expect(completedMessage.imagePath, downloaded.path);
    expect(completedMessage.isMediaLoading, isFalse);

    await repository.disconnect();
  });

  testWidgets('renders a four-photo album without layout errors', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ImageBubble(
            message: Message(
              sender: Sender.ren,
              text: 'Album caption',
              imagePath: 'assets/images/template.jpg',
              albumImagePaths: [
                'assets/images/template.jpg',
                'assets/images/template.jpg',
                'assets/images/template.jpg',
                'assets/images/template.jpg',
              ],
              mediaKind: MessageKind.image,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Album caption'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MediaGateway extends TdlibGateway {
  final _updates = StreamController<TdJson>.broadcast();
  final requests = <TdJson>[];
  var _messageId = 100;
  final TdJson? historyMessage;
  final TdJson? downloadFileResponse;
  var _historyReturned = false;

  _MediaGateway({this.historyMessage, this.downloadFileResponse});

  void emitUpdate(TdJson update) => _updates.add(update);

  @override
  Stream<TdJson> get updates => _updates.stream;

  @override
  Future<void> initialize() async {}

  @override
  Future<TdJson> invoke(
    TdJson request, {
    Duration timeout = const Duration(seconds: 35),
  }) async {
    requests.add(request);
    switch (request['@type']) {
      case 'getAuthorizationState':
        return {'@type': 'authorizationStateReady'};
      case 'getChats':
        return {'@type': 'chats', 'chat_ids': const <int>[]};
      case 'getChatHistory':
        if (historyMessage == null || _historyReturned) {
          return {'@type': 'messages', 'messages': const <TdJson>[]};
        }
        _historyReturned = true;
        return {
          '@type': 'messages',
          'messages': [historyMessage],
        };
      case 'downloadFile':
        return downloadFileResponse ?? {'@type': 'file'};
      case 'sendMessage':
        return _messageFor(
          request['input_message_content'] as TdJson,
          albumId: 0,
        );
      case 'sendMessageAlbum':
        final contents = (request['input_message_contents'] as List)
            .whereType<TdJson>();
        return {
          '@type': 'messages',
          'messages': [
            for (final content in contents) _messageFor(content, albumId: 77),
          ],
        };
      default:
        return {'@type': 'ok'};
    }
  }

  TdJson _messageFor(TdJson input, {required int albumId}) {
    final type = input['@type'];
    final inputFile = switch (type) {
      'inputMessagePhoto' => input['photo'] as TdJson,
      'inputMessageDocument' => input['document'] as TdJson,
      'inputMessageAnimation' => input['animation'] as TdJson,
      'inputMessageSticker' => input['sticker'] as TdJson,
      _ => <String, dynamic>{'path': ''},
    };
    final path = inputFile['path'] as String? ?? '';
    final file = _file(path);
    final caption = input['caption'] as TdJson? ?? _formattedText('');
    final content = switch (type) {
      'inputMessagePhoto' => {
        '@type': 'messagePhoto',
        'photo': {
          '@type': 'photo',
          'sizes': [
            {'@type': 'photoSize', 'width': 100, 'height': 100, 'photo': file},
          ],
        },
        'caption': caption,
      },
      'inputMessageDocument' => {
        '@type': 'messageDocument',
        'document': {
          '@type': 'document',
          'file_name': path.split(Platform.pathSeparator).last,
          'document': file,
        },
        'caption': caption,
      },
      'inputMessageAnimation' => {
        '@type': 'messageAnimation',
        'animation': {'@type': 'animation', 'animation': file},
        'caption': caption,
      },
      'inputMessageSticker' => {
        '@type': 'messageSticker',
        'sticker': {'@type': 'sticker', 'sticker': file},
      },
      _ => {'@type': 'messageText', 'text': _formattedText('')},
    };
    return {
      '@type': 'message',
      'id': _messageId++,
      'chat_id': 42,
      'is_outgoing': true,
      'date': 1,
      'media_album_id': albumId.toString(),
      'content': content,
    };
  }

  TdJson _file(String path) => {
    '@type': 'file',
    'id': _messageId,
    'size': path.isEmpty ? 0 : File(path).lengthSync(),
    'local': {
      '@type': 'localFile',
      'path': path,
      'is_downloading_completed': true,
    },
  };

  TdJson _formattedText(String text) => {
    '@type': 'formattedText',
    'text': text,
    'entities': const <Object>[],
  };

  @override
  Future<void> close() => _updates.close();
}

TdJson _remoteFile(
  int id, {
  required int size,
  int downloadedSize = 0,
  String path = '',
  bool isCompleted = false,
}) => {
  '@type': 'file',
  'id': id,
  'size': size,
  'expected_size': size,
  'local': {
    '@type': 'localFile',
    'path': path,
    'downloaded_size': downloadedSize,
    'is_downloading_active': !isCompleted,
    'is_downloading_completed': isCompleted,
  },
};

TdJson _formattedText(String text) => {
  '@type': 'formattedText',
  'text': text,
  'entities': const <Object>[],
};
