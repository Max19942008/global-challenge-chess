import { Chess, type Move, type Square } from 'chess.js';

export type Color = 'white' | 'black';
export type Result = '1-0' | '0-1' | '1/2-1/2';
export type EndReason =
  | 'checkmate'
  | 'stalemate'
  | 'threefold'
  | 'fifty-move'
  | 'insufficient'
  | 'resign'
  | 'timeout'
  | 'abandon'
  | 'draw-agreed'
  | 'aborted';

export interface GameStatus {
  over: boolean;
  result?: Result;
  reason?: EndReason;
  check: boolean;
  turn: Color;
}

export const PROMOTION_PIECES = ['q', 'r', 'b', 'n'] as const;
export type PromotionPiece = (typeof PROMOTION_PIECES)[number];

const UCI_RE = /^([a-h][1-8])([a-h][1-8])([qrbn])?$/;

export function parseUci(uci: string): { from: Square; to: Square; promotion?: PromotionPiece } | null {
  const m = UCI_RE.exec(uci);
  if (!m) return null;
  return { from: m[1] as Square, to: m[2] as Square, promotion: m[3] as PromotionPiece | undefined };
}

export function toUci(move: Pick<Move, 'from' | 'to' | 'promotion'>): string {
  return move.from + move.to + (move.promotion ?? '');
}

/**
 * Thin wrapper over chess.js. Server and clients import this exact class,
 * so they can never disagree on what is legal or how a game ended.
 */
export class ChessGame {
  private chess: Chess;
  readonly startFen: string;

  constructor(fen?: string) {
    this.chess = fen ? new Chess(fen) : new Chess();
    this.startFen = this.chess.fen();
  }

  static fromUciMoves(moves: readonly string[], fen?: string): ChessGame {
    const g = new ChessGame(fen);
    for (const uci of moves) {
      if (!g.move(uci)) throw new Error(`Illegal move in history: ${uci}`);
    }
    return g;
  }

  get fen(): string {
    return this.chess.fen();
  }

  /** Number of half-moves played since startFen. */
  get ply(): number {
    return this.chess.history().length;
  }

  turn(): Color {
    return this.chess.turn() === 'w' ? 'white' : 'black';
  }

  /** Legal destinations per origin square, in the shape chessground expects. */
  legalDests(): Map<string, string[]> {
    const dests = new Map<string, string[]>();
    for (const m of this.chess.moves({ verbose: true })) {
      const list = dests.get(m.from);
      if (list) {
        if (!list.includes(m.to)) list.push(m.to);
      } else dests.set(m.from, [m.to]);
    }
    return dests;
  }

  isPromotion(from: string, to: string): boolean {
    return this.chess
      .moves({ square: from as Square, verbose: true })
      .some((m) => m.to === to && m.promotion !== undefined);
  }

  /** Applies a UCI move ("e2e4", "e7e8q"). Returns the move, or null if illegal. */
  move(uci: string): Move | null {
    const parsed = parseUci(uci);
    if (!parsed) return null;
    try {
      return this.chess.move(parsed);
    } catch {
      return null;
    }
  }

  undo(): Move | null {
    return this.chess.undo();
  }

  history(): Move[] {
    return this.chess.history({ verbose: true });
  }

  uciHistory(): string[] {
    return this.history().map(toUci);
  }

  lastMove(): [string, string] | undefined {
    const h = this.history();
    const last = h[h.length - 1];
    return last ? [last.from, last.to] : undefined;
  }

  pgn(): string {
    return this.chess.pgn();
  }

  status(): GameStatus {
    const c = this.chess;
    const turn = this.turn();
    const check = c.inCheck();
    if (c.isCheckmate()) {
      return { over: true, result: turn === 'white' ? '0-1' : '1-0', reason: 'checkmate', check, turn };
    }
    const draw = (reason: EndReason): GameStatus => ({ over: true, result: '1/2-1/2', reason, check, turn });
    if (c.isStalemate()) return draw('stalemate');
    if (c.isInsufficientMaterial()) return draw('insufficient');
    if (c.isThreefoldRepetition()) return draw('threefold');
    if (c.isDrawByFiftyMoves()) return draw('fifty-move');
    return { over: false, check, turn };
  }
}
