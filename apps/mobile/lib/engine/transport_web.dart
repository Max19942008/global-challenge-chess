import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'transport_base.dart';

/// Same single-threaded lite build as apps/web; lives in web/stockfish/.
const _engineUrl = 'stockfish/stockfish-19-lite-single.js';

Future<UciTransport> openTransport() async => _WebTransport();

class _WebTransport implements UciTransport {
  _WebTransport() : _worker = web.Worker(_engineUrl.toJS) {
    _worker.onmessage = ((web.MessageEvent e) {
      final data = e.data;
      if (data.isA<JSString>()) _lines.add((data as JSString).toDart);
    }).toJS;
  }

  final web.Worker _worker;
  final _lines = StreamController<String>.broadcast();

  @override
  Stream<String> get lines => _lines.stream;

  @override
  void send(String command) => _worker.postMessage(command.toJS);

  @override
  Future<void> dispose() async {
    _worker.terminate();
    await _lines.close();
  }
}
