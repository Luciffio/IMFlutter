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
      final raw = TdPlugin.instance.tdReceive(0.2);
      if (raw == null) {
        await Future<void>.delayed(const Duration(milliseconds: 16));
        continue;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) continue;

      final extra = decoded['@extra'];
      if (extra is int && _pending.containsKey(extra)) {
        final completer = _pending.remove(extra);
        if (completer != null && !completer.isCompleted) {
          completer.complete(decoded);
        }
        continue;
      }

      _updates.add(decoded);
    }
  }
}
