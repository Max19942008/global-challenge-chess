import { test } from 'node:test';
import assert from 'node:assert/strict';
import { applyMoveToClock, estimateOffset, flagDeadline, initialClock, parseTimeControl, remainingAt } from './clock.ts';

test('parseTimeControl', () => {
  assert.deepEqual(parseTimeControl('5+3'), { initialMs: 300_000, incrementMs: 3000 });
  assert.throws(() => parseTimeControl('5'));
});

test('time is deducted on move, increment added, turn switches', () => {
  const s0 = initialClock(parseTimeControl('3+2'), 1000);
  const { state, flagged } = applyMoveToClock(s0, 11_000);
  assert.equal(flagged, false);
  assert.equal(state.white, 180_000 - 10_000 + 2000);
  assert.equal(state.black, 180_000);
  assert.equal(state.turn, 'black');
  assert.equal(state.lastMoveAt, 11_000);
  assert.equal(flagDeadline(state), 11_000 + 180_000);
});

test('move arriving after time ran out flags', () => {
  const s0 = initialClock(parseTimeControl('1+0'), 0);
  const r = applyMoveToClock(s0, 60_001);
  assert.equal(r.flagged, true);
  assert.equal(r.state.white, 0);
});

test('remainingAt ticks only for side to move', () => {
  const s0 = initialClock(parseTimeControl('1+0'), 0);
  assert.equal(remainingAt(s0, 'white', 5000), 55_000);
  assert.equal(remainingAt(s0, 'black', 5000), 60_000);
});

test('estimateOffset picks the fastest round trip', () => {
  const offset = estimateOffset([
    { sentAt: 0, receivedAt: 400, serverTime: 5300 }, // slow, skewed
    { sentAt: 1000, receivedAt: 1040, serverTime: 3020 }, // fast
  ]);
  assert.equal(offset, 2000);
});
