import 'package:dartchess/dartchess.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaxmat/game/chess_game.dart';

ChessGame playAll(List<String> ucis) {
  final g = ChessGame();
  for (final u in ucis) {
    expect(g.playUci(u), isTrue, reason: 'move $u should be legal');
  }
  return g;
}

void main() {
  test('start position has 20 moves, white to move', () {
    final g = ChessGame();
    final total = g.legalMoves.values.fold<int>(0, (n, d) => n + d.length);
    expect(total, 20);
    expect(g.status.turn, Side.white);
  });

  test('illegal move is rejected', () {
    final g = ChessGame();
    expect(g.playUci('e2e5'), isFalse);
    expect(g.ply, 0);
  });

  test("fool's mate: black wins by checkmate", () {
    final s = playAll(['f2f3', 'e7e5', 'g2g4', 'd8h4']).status;
    expect(s.over, isTrue);
    expect(s.reason, EndReason.checkmate);
    expect(s.winner, Side.black);
    expect(playAll(['f2f3', 'e7e5', 'g2g4', 'd8h4']).moves.last.san, 'Qh4#');
  });

  test('castling as king two squares (how the engine and the board send it)', () {
    final g = playAll(['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4', 'g8f6', 'e1g1']);
    expect(g.moves.last.san, 'O-O');
  });

  test('en passant only right after the double step', () {
    final g = playAll(['e2e4', 'a7a6', 'e4e5', 'd7d5']);
    expect(g.legalMoves[Square.e5]?.contains(Square.d6), isTrue);
    final g2 = playAll(['e2e4', 'a7a6', 'e4e5', 'd7d5', 'h2h3', 'h7h6']);
    expect(g2.legalMoves[Square.e5]?.contains(Square.d6) ?? false, isFalse);
  });

  test('promotion to a knight', () {
    final g = playAll(['a2a4', 'b7b5', 'a4b5', 'a7a6', 'b5a6', 'c8b7', 'a6b7', 'h7h6']);
    expect(g.isPromotion(const NormalMove(from: Square.b7, to: Square.a8)), isTrue);
    expect(g.playUci('b7a8n'), isTrue);
    expect(g.moves.last.san, 'bxa8=N');
  });

  test('threefold repetition is a draw', () {
    final s = playAll(['g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1', 'f6g8']).status;
    expect(s.reason, EndReason.threefold);
    expect(s.winner, isNull);
  });

  test('undo restores the position; no moves after game over', () {
    final g = playAll(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
    expect(g.playUci('a2a3'), isFalse);
    g.undo();
    expect(g.status.over, isFalse);
    expect(g.ply, 3);
  });

  test('resign', () {
    final g = ChessGame()..resigned = Side.white;
    expect(g.status.winner, Side.black);
    expect(g.status.reason, EndReason.resign);
  });
}
