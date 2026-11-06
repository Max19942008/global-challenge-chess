import type { RatingCategory } from '@shaxmat/chess-core';
import { parseTimeControl } from '@shaxmat/chess-core';

/** All waits the server makes. Tests shrink them; production uses the defaults. */
export interface Delays {
  /** Offer a bot after this long in the queue (player stays queued). */
  botOfferMs: number;
  /** A side that hasn't made its first move by then aborts the game (unrated). */
  abortMs: number;
  /** Grace after a disconnect before the opponent may claim the win: games up to 5 min / longer. */
  graceShortMs: number;
  graceLongMs: number;
  matchTickMs: number;
  timerTickMs: number;
  waitingEveryMs: number;
  statsEveryMs: number;
  /** Rating window grows with time in queue: thresholds (ms) and ranges (rating points); past the last threshold anyone matches. */
  windowAfterMs: [number, number, number];
  windowRange: [number, number, number];
}

export const defaultDelays: Delays = {
  botOfferMs: 15_000,
  abortMs: 30_000,
  graceShortMs: 20_000,
  graceLongMs: 40_000,
  matchTickMs: 1_000,
  timerTickMs: 150,
  waitingEveryMs: 2_000,
  statsEveryMs: 5_000,
  windowAfterMs: [5_000, 15_000, 30_000],
  windowRange: [100, 200, 400],
};

export const defaultTimeControls = ['3+0', '5+0', '10+0'];

/** 3+0 and 5+0 are blitz, 10+0 rapid; anything under 3 minutes is bullet (reserved). */
export function categoryOf(tc: string): RatingCategory {
  const minutes = parseTimeControl(tc).initialMs / 60_000;
  if (minutes < 3) return 'bullet';
  if (minutes < 8) return 'blitz';
  return 'rapid';
}

export const categories: RatingCategory[] = ['bullet', 'blitz', 'rapid'];
