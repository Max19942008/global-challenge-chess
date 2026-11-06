/**
 * Stockfish in a Web Worker: runs in the player's own browser, so bot games
 * cost the server nothing and never touch it.
 */

export type BotLevel = 'beginner' | 'intermediate' | 'strong';

export interface BotLevelInfo {
  label: string;
  /** Internal target only. Not shown as a rating: UCI_Elo is calibrated at 120s+1s vs CCRL, not our ratings. */
  targetElo: number;
  movetimeMs: number;
}

export const BOT_LEVELS: Record<BotLevel, BotLevelInfo> = {
  beginner: { label: 'Boshlovchi', targetElo: 800, movetimeMs: 250 },
  intermediate: { label: "O'rta", targetElo: 1500, movetimeMs: 500 },
  strong: { label: 'Kuchli', targetElo: 2200, movetimeMs: 1000 },
};

/** UCI_Elo cannot go below this; weaker bots use Skill Level instead. */
const UCI_ELO_MIN = 1320;
const UCI_ELO_MAX = 3190;

/**
 * Elo -> Skill Level 0..20. Stockfish documents no such mapping; this is an
 * uncalibrated starting guess. Tune it from real results against each level.
 */
export function skillFor(targetElo: number): number {
  return Math.max(0, Math.min(20, Math.round((targetElo - 500) / 100)));
}

const ENGINE_URL = '/stockfish/stockfish-19-lite-single.js';

export class StockfishEngine {
  private worker: Worker;
  private waiters: { match: (line: string) => boolean; resolve: (line: string) => void }[] = [];
  /** Commands run one at a time, so a stale search can never answer a newer request. */
  private queue: Promise<unknown>;

  constructor() {
    this.worker = new Worker(ENGINE_URL);
    this.worker.onmessage = (e: MessageEvent) => {
      const line = typeof e.data === 'string' ? e.data : String(e.data);
      const i = this.waiters.findIndex((w) => w.match(line));
      if (i >= 0) this.waiters.splice(i, 1)[0]!.resolve(line);
    };
    this.queue = (async () => {
      this.send('uci');
      await this.waitFor((l) => l === 'uciok');
      await this.isReady();
    })();
  }

  private enqueue<T>(task: () => Promise<T>): Promise<T> {
    const run = this.queue.then(task, task);
    this.queue = run.catch(() => undefined);
    return run;
  }

  private send(cmd: string) {
    this.worker.postMessage(cmd);
  }

  private waitFor(match: (line: string) => boolean): Promise<string> {
    return new Promise((resolve) => this.waiters.push({ match, resolve }));
  }

  private async isReady() {
    this.send('isready');
    await this.waitFor((l) => l === 'readyok');
  }

  newGame(level: BotLevel): Promise<void> {
    return this.enqueue(() => this.configure(level));
  }

  private async configure(level: BotLevel) {
    const { targetElo } = BOT_LEVELS[level];
    this.send('ucinewgame');
    if (targetElo >= UCI_ELO_MIN) {
      this.send('setoption name UCI_LimitStrength value true');
      this.send(`setoption name UCI_Elo value ${Math.min(targetElo, UCI_ELO_MAX)}`);
    } else {
      this.send('setoption name UCI_LimitStrength value false');
      this.send(`setoption name Skill Level value ${skillFor(targetElo)}`);
    }
    await this.isReady();
  }

  /** Returns the engine's move in UCI notation ("e2e4", "e7e8q"), or null if it has none. */
  bestMove(fen: string, movetimeMs: number): Promise<string | null> {
    return this.enqueue(async () => {
      this.send(`position fen ${fen}`);
      this.send(`go movetime ${movetimeMs}`);
      const line = await this.waitFor((l) => l.startsWith('bestmove'));
      const move = line.split(/\s+/)[1];
      return move && move !== '(none)' ? move : null;
    });
  }

  terminate() {
    this.worker.terminate();
    this.waiters = [];
  }
}
