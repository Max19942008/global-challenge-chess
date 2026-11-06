import glicko2 from 'glicko2';

const { Glicko2 } = glicko2 as unknown as {
  Glicko2: new (s: { tau: number; rating: number; rd: number; vol: number }) => {
    makePlayer(r: number, rd: number, vol: number): { getRating(): number; getRd(): number; getVol(): number };
    updateRatings(m: unknown[]): void;
  };
};

export interface Rating {
  rating: number;
  rd: number;
  vol: number;
}

export const DEFAULT_RATING: Rating = { rating: 1500, rd: 350, vol: 0.06 };

/** Above this deviation the rating is shown with a "?". */
export const PROVISIONAL_RD = 110;

export const isProvisional = (r: Rating) => r.rd > PROVISIONAL_RD;

/**
 * One rated game, Glicko-2 (tau 0.5). Each game is its own rating period, as
 * on Lichess. The library is checked against Glickman's worked example in tests.
 */
export function rateGame(white: Rating, black: Rating, whiteScore: 1 | 0.5 | 0): { white: Rating; black: Rating } {
  const g = new Glicko2({ tau: 0.5, ...DEFAULT_RATING });
  const w = g.makePlayer(white.rating, white.rd, white.vol);
  const b = g.makePlayer(black.rating, black.rd, black.vol);
  g.updateRatings([[w, b, whiteScore]]);
  const out = (p: typeof w): Rating => ({ rating: p.getRating(), rd: p.getRd(), vol: p.getVol() });
  return { white: out(w), black: out(b) };
}

/** Raw access for the reference test. */
export function glickoForTest() {
  return new Glicko2({ tau: 0.5, ...DEFAULT_RATING });
}
