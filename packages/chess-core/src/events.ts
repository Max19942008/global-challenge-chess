/**
 * WebSocket protocol, version 1. Shared by the web client, the Flutter client
 * and the server. Every message is one JSON object: { v: 1, type, ...payload }.
 * The server is the only source of truth: clients send intents, never state.
 * Human-readable copy: docs/protocol.md (keep both in sync).
 */
import type { Color, EndReason, Result } from './rules.ts';

export const PROTOCOL_VERSION = 1 as const;

type Msg<T extends string, P = {}> = { v: typeof PROTOCOL_VERSION; type: T } & P;

export interface Clocks {
  white: number;
  black: number;
}

/** "3+0" | "5+0" | "10+0" for now. */
export type TimeControlId = string;
export type RatingCategory = 'bullet' | 'blitz' | 'rapid';

export interface PlayerInfo {
  id: string;
  name: string;
  rating?: number;
  /** Rating deviation is still high: show the rating with a "?". */
  provisional?: boolean;
  isBot?: boolean;
}

export interface UserInfo {
  id: string;
  name: string;
  ratings: Record<RatingCategory, { rating: number; provisional: boolean }>;
}

export type ClientMessage =
  /** First contact without an account: the server creates a guest and returns a token. */
  | Msg<'auth:guest', { name?: string }>
  /** Every later connection: the token from auth:ok. */
  | Msg<'auth', { token: string }>
  /** Clock-offset sampling. The client sends its own Date.now() as t. */
  | Msg<'ping', { t: number }>
  | Msg<'queue:join', { timeControl: TimeControlId; rated: boolean }>
  | Msg<'queue:leave'>
  | Msg<'queue:botAccept'>
  | Msg<'queue:botDecline'>
  | Msg<'game:move', { gameId: string; uci: string; ply: number }>
  | Msg<'game:resign', { gameId: string }>
  | Msg<'game:drawOffer', { gameId: string }>
  | Msg<'game:drawRespond', { gameId: string; accept: boolean }>
  | Msg<'game:sync', { gameId: string }>
  /** Allowed only after opponent:abandoned for this game. */
  | Msg<'game:claimVictory', { gameId: string }>;

export type ServerMessage =
  | Msg<'auth:ok', { token: string; user: UserInfo }>
  | Msg<'pong', { t: number; serverTime: number }>
  /** Sent after auth and every ~5 s to everyone: drives the "online now" counter. */
  | Msg<'lobby:stats', { onlineCount: number }>
  | Msg<'queue:waiting', { elapsedMs: number; onlineCount: number }>
  /** The player stays in the queue while this is shown. */
  | Msg<'queue:botOffer', { suggestedElo: number }>
  | Msg<'queue:left'>
  | Msg<
      'game:start',
      {
        gameId: string;
        color: Color;
        opponent: PlayerInfo;
        timeControl: TimeControlId;
        rated: boolean;
        fen: string;
        clocks: Clocks;
        serverTime: number;
      }
    >
  | Msg<'game:move', { gameId: string; uci: string; fen: string; ply: number; clocks: Clocks; serverTime: number }>
  /** Full state: answer to game:sync, and sent unasked right after auth when a game is in progress. */
  | Msg<
      'game:state',
      {
        gameId: string;
        fen: string;
        ply: number;
        moves: string[];
        turn: Color;
        clocks: Clocks;
        serverTime: number;
        color: Color;
        white: PlayerInfo;
        black: PlayerInfo;
        timeControl: TimeControlId;
        rated: boolean;
      }
    >
  | Msg<'game:drawOffer', { gameId: string; from: Color }>
  | Msg<'game:drawDeclined', { gameId: string }>
  | Msg<
      'game:end',
      {
        gameId: string;
        result: Result;
        reason: EndReason;
        /** Rating change of the receiving player; absent for unrated/aborted games. */
        ratingChange?: { before: number; after: number };
      }
    >
  | Msg<'opponent:disconnected', { gameId: string; graceMs: number }>
  | Msg<'opponent:reconnected', { gameId: string }>
  /** Grace period ran out: the receiver may now send game:claimVictory (or keep waiting). */
  | Msg<'opponent:abandoned', { gameId: string }>
  | Msg<'error', { code: string; message: string }>;
