import 'package:multistockfish/multistockfish.dart';

import 'transport_base.dart';

Future<UciTransport> openTransport() async =>
    _NativeTransport(await Stockfish.create(flavor: StockfishFlavor.light));

class _NativeTransport implements UciTransport {
  _NativeTransport(this._engine);
  final Stockfish _engine;

  @override
  Stream<String> get lines => _engine.stdout;

  @override
  void send(String command) => _engine.stdin = command;

  @override
  Future<void> dispose() => _engine.dispose();
}
