import type { Color } from './rules.ts';

export interface TimeControl {
  initialMs: number;
  incrementMs: number;
}

/** "5+3" -> 5 minutes, 3 seconds increment. */
export function parseTimeControl(tc: string): TimeControl {
  const m = /^(\d+(?:\.\d+)?)\+(\d+)$/.exec(tc.trim());
  if (!m) throw new Error(`Bad time control: ${tc}`);
  return { initialMs: Math.round(Number(m[1]) * 60_000), incrementMs: Number(m[2]) * 1000 };
}

export interface ClockState {
  white: number;
  black: number;
  turn: Color;
  /** Server time when the last move was accepted (or the game started). */
  lastMoveAt: number;
  incrementMs: number;
}

export function initialClock(tc: TimeControl, now: number): ClockState {
  return { white: tc.initialMs, black: tc.initialMs, turn: 'white', lastMoveAt: now, incrementMs: tc.incrementMs };
}

/**
 * Time is deducted only when a move arrives; the server never ticks.
 * Returns flagged=true if the mover had already run out.
 */
export function applyMoveToClock(state: ClockState, now: number): { state: ClockState; flagged: boolean } {
  const elapsed = Math.max(0, now - state.lastMoveAt);
  const left = state[state.turn] - elapsed;
  if (left <= 0) {
    return { state: { ...state, [state.turn]: 0 }, flagged: true };
  }
  const next: ClockState = {
    ...state,
    [state.turn]: left + state.incrementMs,
    turn: state.turn === 'white' ? 'black' : 'white',
    lastMoveAt: now,
  };
  return { state: next, flagged: false };
}

/** When the side to move flags if no move arrives: the timer the server schedules. */
export function flagDeadline(state: ClockState): number {
  return state.lastMoveAt + state[state.turn];
}

/** Display value for a side at a given moment (client-side ticking, display only). */
export function remainingAt(state: ClockState, color: Color, now: number): number {
  if (color !== state.turn) return state[color];
  return Math.max(0, state[color] - Math.max(0, now - state.lastMoveAt));
}

export interface OffsetSample {
  sentAt: number;
  receivedAt: number;
  serverTime: number;
}

/**
 * Client/server clock offset: use the sample with the smallest round trip
 * (the fastest reply is the most accurate). serverNow = Date.now() + offset.
 */
export function estimateOffset(samples: readonly OffsetSample[]): number {
  if (samples.length === 0) throw new Error('No samples');
  let best = samples[0]!;
  for (const s of samples) if (s.receivedAt - s.sentAt < best.receivedAt - best.sentAt) best = s;
  return best.serverTime - (best.sentAt + best.receivedAt) / 2;
}
