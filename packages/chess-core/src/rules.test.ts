import { test } from 'node:test';
import assert from 'node:assert/strict';
import { ChessGame } from './rules.ts';

test('start position: 20 legal moves, white to move', () => {
  const g = new ChessGame();
  const total = [...g.legalDests().values()].reduce((n, d) => n + d.length, 0);
  assert.equal(total, 20);
  assert.equal(g.turn(), 'white');
});

test('illegal move returns null and does not change position', () => {
  const g = new ChessGame();
  const fen = g.fen;
  assert.equal(g.move('e2e5'), null);
  assert.equal(g.move('garbage'), null);
  assert.equal(g.fen, fen);
});

test('fool’s mate is checkmate, black wins', () => {
  const g = ChessGame.fromUciMoves(['f2f3', 'e7e5', 'g2g4', 'd8h4']);
  assert.deepEqual(g.status(), { over: true, result: '0-1', reason: 'checkmate', check: true, turn: 'white' });
});

test('en passant only on the very next move', () => {
  const g = ChessGame.fromUciMoves(['e2e4', 'a7a6', 'e4e5', 'd7d5']);
  assert.ok(g.legalDests().get('e5')?.includes('d6'));
  const g2 = ChessGame.fromUciMoves(['e2e4', 'a7a6', 'e4e5', 'd7d5', 'h2h3', 'h7h6']);
  assert.ok(!g2.legalDests().get('e5')?.includes('d6'));
});

test('castling lost after king moves, forbidden through check', () => {
  const moved = new ChessGame('r3k2r/8/8/8/8/8/8/R3K2R w KQkq - 0 1');
  moved.move('e1f1');
  moved.move('a8b8');
  moved.move('f1e1');
  moved.move('b8a8');
  assert.ok(!moved.legalDests().get('e1')?.includes('g1'));

  // black rook on f8 attacks f1: white may not castle kingside through it
  const through = new ChessGame('4kr2/8/8/8/8/8/8/4K2R w K - 0 1');
  assert.ok(!through.legalDests().get('e1')?.includes('g1'));
});

test('promotion: four choices, detected as promotion', () => {
  const g = new ChessGame('8/P7/8/8/8/8/8/k6K w - - 0 1');
  assert.ok(g.isPromotion('a7', 'a8'));
  assert.ok(!g.isPromotion('h1', 'h2'));
  assert.equal(g.move('a7a8n')?.promotion, 'n');
});

test('stalemate is a draw', () => {
  const g = new ChessGame('7k/5Q2/6K1/8/8/8/8/8 b - - 0 1');
  assert.equal(g.status().reason, 'stalemate');
  assert.equal(g.status().result, '1/2-1/2');
});

test('threefold repetition is a draw', () => {
  const g = ChessGame.fromUciMoves(['g1f3', 'g8f6', 'f3g1', 'f6g8', 'g1f3', 'g8f6', 'f3g1', 'f6g8']);
  assert.equal(g.status().reason, 'threefold');
});

test('insufficient material: K+B vs K', () => {
  assert.equal(new ChessGame('8/8/8/4k3/8/8/8/2B1K3 w - - 0 1').status().reason, 'insufficient');
});

test('fifty-move rule', () => {
  assert.equal(new ChessGame('8/8/8/4k3/8/8/8/R3K3 w - - 100 80').status().reason, 'fifty-move');
});

test('uciHistory round-trips through fromUciMoves', () => {
  const moves = ['e2e4', 'e7e5', 'g1f3', 'b8c6', 'f1c4'];
  const g = ChessGame.fromUciMoves(moves);
  assert.deepEqual(g.uciHistory(), moves);
  assert.equal(g.ply, 5);
  assert.deepEqual(g.lastMove(), ['f1', 'c4']);
});
