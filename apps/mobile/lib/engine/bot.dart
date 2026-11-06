import 'dart:async';

import 'transport.dart';

enum BotLevel { beginner, intermediate, strong }

class BotLevelInfo {
  const BotLevelInfo(this.targetElo, this.movetimeMs);

  /// Internal target only, never shown as a rating: UCI_Elo is calibrated at
  /// 120s+1s against CCRL, not against our players.
  final int targetElo;
  final int movetimeMs;
}

const botLevels = <BotLevel, BotLevelInfo>{
  BotLevel.beginner: BotLevelInfo(800, 250),
  BotLevel.intermediate: BotLevelInfo(1500, 500),
  BotLevel.strong: BotLevelInfo(2200, 1000),
};

/// UCI_Elo cannot go below this; weaker bots use Skill Level instead.
const _uciEloMin = 1320;
const _uciEloMax = 3190;

/// Elo -> Skill Level 0..20. Same uncalibrated starting guess as the web app
/// (apps/web/lib/engine.ts). Tune it from real results.
int skillFor(int targetElo) => ((targetElo - 500) / 100).round().clamp(0, 20);

/// What the game screen needs from an engine. Lets tests swap in a fake.
abstract interface class ChessBot {
  Future<void> newGame(BotLevel level);

  /// The engine's move in UCI ("e2e4", "e7e8q"), or null if it has none.
  Future<String?> bestMove(String fen, int movetimeMs);
  Future<void> dispose();
}

typedef BotFactory = Future<ChessBot> Function();

/// Stockfish 19, running on the device: natively on Android/iOS, as WASM in a
/// browser (see transport.dart). Bot games never reach the server.
class StockfishBot implements ChessBot {
  StockfishBot._(this._engine) {
    _sub = _engine.lines.listen(_onLine);
  }

  final UciTransport _engine;
  late final StreamSubscription<String> _sub;
  final List<({bool Function(String) match, Completer<String> done})> _waiters = [];

  /// Commands run one at a time, so a stale search can never answer a newer request.
  Future<void> _queue = Future.value();

  static Future<StockfishBot> start() async {
    final engine = await openTransport();
    final bot = StockfishBot._(engine);
    await bot._enqueue(() async {
      bot._send('uci');
      await bot._waitFor((l) => l == 'uciok');
      await bot._isReady();
    });
    return bot;
  }

  void _onLine(String line) {
    final i = _waiters.indexWhere((w) => w.match(line));
    if (i >= 0) _waiters.removeAt(i).done.complete(line);
  }

  void _send(String cmd) => _engine.send(cmd);

  Future<String> _waitFor(bool Function(String) match) {
    final c = Completer<String>();
    _waiters.add((match: match, done: c));
    return c.future;
  }

  Future<void> _isReady() async {
    _send('isready');
    await _waitFor((l) => l == 'readyok');
  }

  Future<T> _enqueue<T>(Future<T> Function() task) {
    final run = _queue.then((_) => task());
    _queue = run.then((_) {}, onError: (_) {});
    return run;
  }

  @override
  Future<void> newGame(BotLevel level) => _enqueue(() async {
        final elo = botLevels[level]!.targetElo;
        _send('ucinewgame');
        if (elo >= _uciEloMin) {
          _send('setoption name UCI_LimitStrength value true');
          _send('setoption name UCI_Elo value ${elo.clamp(_uciEloMin, _uciEloMax)}');
        } else {
          _send('setoption name UCI_LimitStrength value false');
          _send('setoption name Skill Level value ${skillFor(elo)}');
        }
        await _isReady();
      });

  @override
  Future<String?> bestMove(String fen, int movetimeMs) => _enqueue(() async {
        _send('position fen $fen');
        _send('go movetime $movetimeMs');
        final line = await _waitFor((l) => l.startsWith('bestmove'));
        final parts = line.split(RegExp(r'\s+'));
        final move = parts.length > 1 ? parts[1] : null;
        return (move == null || move == '(none)') ? null : move;
      });

  @override
  Future<void> dispose() async {
    await _sub.cancel();
    _waiters.clear();
    await _engine.dispose();
  }
}
