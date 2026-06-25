import 'dart:async';
import 'dart:convert';

import 'package:handy_tdlib/client.dart';

typedef TdJson = Map<String, dynamic>;

class TdlibGateway {
  final _updates = StreamController<TdJson>.broadcast();
  final _pending = <int, Completer<TdJson>>{};

  var _extraSerial = 0;
  var _clientId = 0;
  var _running = false;
  var _initialized = false;

  Stream<TdJson> get updates => _updates.stream;

  Future<void> initialize() async {
    if (_initialized) return;
    await TdPlugin.initialize();
    TdPlugin.instance.tdExecute(
      jsonEncode({
        '@type': 'setLogVerbosityLevel',
        'new_verbosity_level': 1,
      }),
    );
    _clientId = TdPlugin.instance.tdCreateClientId();
    _running = true;
    _initialized = true;
    unawaited(_receiveLoop());
  }

  Future<TdJson> invoke(
    TdJson request, {
    Duration timeout = const Duration(seconds: 35),
  }) async {
    await initialize();

    final extra = ++_extraSerial;
    final completer = Completer<TdJson>();
    _pending[extra] = completer;
    send({...request, '@extra': extra});

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        _pending.remove(extra);
        throw TimeoutException('TDLib request timed out: ${request['@type']}');
      },
    );
  }

  void send(TdJson request) {
    if (!_initialized) {
      throw StateError('TDLib gateway is not initialized');
    }
    TdPlugin.instance.tdSend(_clientId, jsonEncode(request));
  }

  Future<void> resetClient() async {
    await initialize();
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('TDLib client reset'));
      }
    }
    _pending.clear();
    _clientId = TdPlugin.instance.tdCreateClientId();
  }

  Future<void> close() async {
    if (_initialized && _running) {
      send({'@type': 'close'});
    }
    _running = false;
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('TDLib gateway closed'));
      }
    }
    _pending.clear();
    await _updates.close();
  }

  Future<void> _receiveLoop() async {
    while (_running) {
      final raw = TdPlugin.instance.tdReceive(0);
      if (raw == null) {
        await Future<void>.delayed(const Duration(milliseconds: 80));
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) continue;

      final extra = decoded['@extra'];
      if (extra is int && _pending.containsKey(extra)) {
        final completer = _pending.remove(extra);
        if (completer != null && !completer.isCompleted) {
          if (decoded['@type'] == 'error') {
            completer.completeError(TdlibException.fromJson(decoded));
          } else {
            completer.complete(decoded);
          }
        }
        continue;
      }

      _updates.add(decoded);
    }
  }
}

class TdlibException implements Exception {
  final int? code;
  final String message;

  const TdlibException({required this.message, this.code});

  factory TdlibException.fromJson(TdJson json) {
    return TdlibException(
      code: json['code'] as int?,
      message: json['message'] as String? ?? 'TDLib error',
    );
  }

  @override
  String toString() {
    if (code == null) return message;
    return '$message ($code)';
  }
}
