import 'dart:math';

import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaxmat/engine/bot.dart';
import 'package:shaxmat/engine/think_time.dart';

Position _fen(String fen) => Chess.fromSetup(Setup.parseFen(fen));

/// A middlegame with plenty of choice (Italian game after a few moves).
final _middlegame = _fen('r1bq1rk1/pppp1ppp/2n2n2/2b1p3/2B1P3/2NP1N2/PPP2PPP/R1BQ1RK1 w - - 4 7');

List<int> _samples(Position pos, int ply, BotLevel level, [int count = 400]) {
  final rng = Random(7);
  return [for (var i = 0; i < count; i++) humanThinkTime(pos, ply, level, random: rng).inMilliseconds];
}

double _mean(List<int> xs) => xs.reduce((a, b) => a + b) / xs.length;

void main() {
  test('never instant, never endless', () {
    for (final level in BotLevel.values) {
      final ms = _samples(_middlegame, 12, level);
      expect(ms.reduce(min), greaterThanOrEqualTo(1500), reason: '$level');
      expect(ms.reduce(max), lessThanOrEqualTo(maxThinkMs), reason: '$level');
    }
  });

  test('varies from move to move, like a person', () {
    final ms = _samples(_middlegame, 12, BotLevel.intermediate);
    expect(ms.toSet().length, greaterThan(300));
  });

  test('opening moves are quicker than the middlegame', () {
    final opening = _samples(Chess.initial, 1, BotLevel.strong);
    final middle = _samples(_middlegame, 12, BotLevel.strong);
    expect(opening.reduce(max), lessThanOrEqualTo(2000));
    expect(_mean(opening), lessThan(_mean(middle)));
  });

  test('a forced move (only one legal reply) is played fast', () {
    // Black king in check from the rook on h1; the knight covers g8 and h7, so Kg7 is the only move.
    final forced = _fen('7k/8/5N2/8/8/8/8/K6R b - - 0 40');
    expect(makeLegalMoves(forced).values.fold<int>(0, (n, t) => n + t.length), 1);
    expect(_samples(forced, 79, BotLevel.strong).reduce(max), lessThanOrEqualTo(1200));
  });

  test('stronger levels think a little longer on average', () {
    final beginner = _mean(_samples(_middlegame, 12, BotLevel.beginner));
    final strong = _mean(_samples(_middlegame, 12, BotLevel.strong));
    expect(strong, greaterThan(beginner));
  });
}
