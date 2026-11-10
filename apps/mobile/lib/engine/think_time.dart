import 'dart:math';

import 'package:dartchess/dartchess.dart';

import 'bot.dart';

/// How long the AI waits before moving. The engine searches during this time;
/// the wait only makes it feel like a person at the board instead of an instant reply.
typedef ThinkTime = Duration Function(Position position, int ply, BotLevel level);

/// Never waits. For tests.
Duration noThinkTime(Position position, int ply, BotLevel level) => Duration.zero;

/// Usual thinking range per level, in milliseconds. Stronger players take a little longer.
const _rangeMs = <BotLevel, (int, int)>{
  BotLevel.beginner: (1500, 4000),
  BotLevel.intermediate: (2000, 5500),
  BotLevel.strong: (2500, 7000),
};

/// Longest wait, even after a "deep think".
const maxThinkMs = 12000;

final _random = Random();

/// A person-like pause:
/// - only one legal move: a quick, almost automatic reply;
/// - the first few moves of the game: book moves, played fairly fast;
/// - check or many possible moves: a bit longer;
/// - now and then (1 in 8) a much longer think.
Duration humanThinkTime(Position position, int ply, BotLevel level, {Random? random}) {
  final rng = random ?? _random;
  // Average of two draws: most waits land mid-range, extremes are rare.
  double between(int low, int high) => low + (high - low) * (rng.nextDouble() + rng.nextDouble()) / 2;

  final moves = makeLegalMoves(position).values.fold<int>(0, (n, targets) => n + targets.length);
  if (moves <= 1) return Duration(milliseconds: between(600, 1200).round());
  if (ply < 6) return Duration(milliseconds: between(800, 2000).round());

  final (low, high) = _rangeMs[level]!;
  var ms = between(low, high);
  if (position.isCheck) ms *= 1.25;
  if (moves > 35) ms *= 1.2;
  if (rng.nextInt(8) == 0) ms *= 1.7;
  return Duration(milliseconds: min(ms, maxThinkMs.toDouble()).round());
}
