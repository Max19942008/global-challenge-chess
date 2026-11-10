import { randomBytes } from 'node:crypto';

import {
  ChessGame,
  parseTimeControl,
  type AvatarPath,
  type ClientMessage,
  type Clocks,
  type Color,
  type EndReason,
  type PlayerInfo,
  type Result,
} from '@shaxmat/chess-core';

import { categoryOf } from './config.ts';
import { errorMsg, msg, type Conn, type Ctx, type Out } from './context.ts';
import type { Lobby } from './lobby.ts';
import { rateGame } from './rating.ts';
import { ratingOf } from './users.ts';

/** A player taking a seat in a new game (from the queue or a challenge). */
export interface Seat {
  userId: string;
  name: string;
  tc: string;
  rated: boolean;
  rating: number;
  provisional: boolean;
  avatar: AvatarPath;
}

/** Game as stored in the Redis hash game:{id}. */
export interface GameRec {
  id: string;
  white: string;
  black: string;
  whiteName: string;
  blackName: string;
  whiteRating: number;
  blackRating: number;
  whiteProv: boolean;
  blackProv: boolean;
  whiteAvatar: AvatarPath;
  blackAvatar: AvatarPath;
  tc: string;
  rated: boolean;
  status: 'active' | 'over';
  fen: string;
  ply: number;
  turn: Color;
  clockW: number;
  clockB: number;
  inc: number;
  lastMoveAt: number;
  startedAt: number;
  drawOffer: '' | Color;
  abandoned: '' | Color;
}

export type GameAction = Extract<ClientMessage, { gameId: string }>;

const other = (c: Color): Color => (c === 'white' ? 'black' : 'white');
const winResult = (winner: Color): Result => (winner === 'white' ? '1-0' : '0-1');

/** Winner-side check for timeouts: a lone king, or king + one minor piece, cannot mate. */
function cannotMate(fen: string, side: Color): boolean {
  const board = fen.split(' ')[0]!;
  const pieces = [...board].filter((ch) => (side === 'white' ? /[PNBRQ]/ : /[pnbrq]/).test(ch));
  return pieces.length === 0 || (pieces.length === 1 && /[nbNB]/.test(pieces[0]!));
}

export type Games = ReturnType<typeof createGames>;

export function createGames(ctx: Ctx, lobby: Lobby) {
  const { r, db, d, log, toUser, toGame, withLock } = ctx;
  const lockKey = (id: string) => `lock:game:${id}`;

  async function load(id: string): Promise<GameRec | null> {
    const h = await r.hgetall(`game:${id}`);
    if (!h || !h.id) return null;
    return {
      id: h.id,
      white: h.white!,
      black: h.black!,
      whiteName: h.whiteName!,
      blackName: h.blackName!,
      whiteRating: Number(h.whiteRating),
      blackRating: Number(h.blackRating),
      whiteProv: h.whiteProv === '1',
      blackProv: h.blackProv === '1',
      whiteAvatar: h.whiteAvatar || null,
      blackAvatar: h.blackAvatar || null,
      tc: h.tc!,
      rated: h.rated === '1',
      status: h.status as GameRec['status'],
      fen: h.fen!,
      ply: Number(h.ply),
      turn: h.turn as Color,
      clockW: Number(h.clockW),
      clockB: Number(h.clockB),
      inc: Number(h.inc),
      lastMoveAt: Number(h.lastMoveAt),
      startedAt: Number(h.startedAt),
      drawOffer: (h.drawOffer ?? '') as GameRec['drawOffer'],
      abandoned: (h.abandoned ?? '') as GameRec['abandoned'],
    };
  }

  const colorOf = (g: GameRec, userId: string): Color | null =>
    g.white === userId ? 'white' : g.black === userId ? 'black' : null;
  const userOf = (g: GameRec, c: Color) => (c === 'white' ? g.white : g.black);

  /** Remaining time as of `now`. Clocks run only from ply 2 (each side's first move is free, guarded by the abort timer). */
  function clocksAt(g: GameRec, now: number): Clocks {
    const c = { white: g.clockW, black: g.clockB };
    if (g.status === 'active' && g.ply >= 2) c[g.turn] = Math.max(0, c[g.turn] - (now - g.lastMoveAt));
    return c;
  }

  const playerInfo = (g: GameRec, c: Color): PlayerInfo =>
    c === 'white'
      ? { id: g.white, name: g.whiteName, rating: g.whiteRating, provisional: g.whiteProv, avatar: g.whiteAvatar }
      : { id: g.black, name: g.blackName, rating: g.blackRating, provisional: g.blackProv, avatar: g.blackAvatar };

  async function stateMsg(g: GameRec, forUser: string): Promise<Out> {
    const now = Date.now();
    return msg('game:state', {
      gameId: g.id,
      fen: g.fen,
      ply: g.ply,
      moves: await r.lrange(`game:${g.id}:moves`, 0, -1),
      turn: g.turn,
      clocks: clocksAt(g, now),
      serverTime: now,
      color: colorOf(g, forUser) ?? 'white',
      white: playerInfo(g, 'white'),
      black: playerInfo(g, 'black'),
      timeControl: g.tc,
      rated: g.rated,
    });
  }

  const sendState = async (g: GameRec, userId: string) => toUser(userId, await stateMsg(g, userId));

  // ---------- start ----------

  async function create(a: Seat, b: Seat) {
    const [w, bl] = Math.random() < 0.5 ? [a, b] : [b, a];
    const id = randomBytes(6).toString('base64url');
    const { initialMs, incrementMs } = parseTimeControl(a.tc);
    const now = Date.now();
    const fen = new ChessGame().fen;
    const tx = r.multi();
    tx.hset(`game:${id}`, {
      id,
      white: w.userId,
      black: bl.userId,
      whiteName: w.name,
      blackName: bl.name,
      whiteRating: String(Math.round(w.rating)),
      blackRating: String(Math.round(bl.rating)),
      whiteProv: w.provisional ? '1' : '0',
      blackProv: bl.provisional ? '1' : '0',
      whiteAvatar: w.avatar ?? '',
      blackAvatar: bl.avatar ?? '',
      tc: a.tc,
      rated: a.rated ? '1' : '0',
      status: 'active',
      fen,
      ply: '0',
      turn: 'white',
      clockW: String(initialMs),
      clockB: String(initialMs),
      inc: String(incrementMs),
      lastMoveAt: String(now),
      startedAt: String(now),
      drawOffer: '',
      abandoned: '',
    });
    tx.set(`user:${w.userId}:game`, id);
    tx.set(`user:${bl.userId}:game`, id);
    tx.zadd('timers', now + d.abortMs, `${id}:abort`);
    await tx.exec();

    const clocks = { white: initialMs, black: initialMs };
    for (const [me, opp, color] of [
      [w, bl, 'white'],
      [bl, w, 'black'],
    ] as const) {
      await toUser(
        me.userId,
        msg('game:start', {
          gameId: id,
          color,
          opponent: { id: opp.userId, name: opp.name, rating: Math.round(opp.rating), provisional: opp.provisional, avatar: opp.avatar },
          timeControl: a.tc,
          rated: a.rated,
          fen,
          clocks,
          serverTime: now,
        }),
      );
    }
    lobby.changed();
    log(`game ${id}: ${w.name} vs ${bl.name} ${a.tc}${a.rated ? ' rated' : ''}`);
    return id;
  }

  // ---------- end ----------

  /** Must be called holding the game lock. */
  async function endLocked(g: GameRec, result: Result, reason: EndReason) {
    if (g.status !== 'active') return;
    g.status = 'over';
    const now = Date.now();
    const moves = await r.lrange(`game:${g.id}:moves`, 0, -1);
    const tx = r.multi();
    tx.hset(`game:${g.id}`, { status: 'over', result, reason });
    tx.zrem('timers', `${g.id}:flag`, `${g.id}:abort`, `${g.id}:grace:white`, `${g.id}:grace:black`);
    tx.expire(`game:${g.id}`, 3600);
    tx.expire(`game:${g.id}:moves`, 3600);
    await tx.exec();
    for (const u of [g.white, g.black]) {
      if ((await r.get(`user:${u}:game`)) === g.id) await r.del(`user:${u}:game`);
    }

    let change: Partial<Record<Color, { before: number; after: number }>> = {};
    try {
      change = await saveFinished(g, result, reason, moves, now);
    } catch (e) {
      log(`saving game ${g.id} failed: ${e}`);
    }

    lobby.changed();
    for (const c of ['white', 'black'] as const) {
      const ratingChange = change[c];
      await toUser(userOf(g, c), msg('game:end', { gameId: g.id, result, reason, ...(ratingChange ? { ratingChange } : {}) }));
    }
  }

  /** Game row, ratings and win/loss/draw counters in one transaction. Returns the rating changes. */
  async function saveFinished(g: GameRec, result: Result, reason: EndReason, moves: string[], now: number) {
    const rated = g.rated && reason !== 'aborted';
    const cat = categoryOf(g.tc);
    let pgn = '';
    try {
      pgn = ChessGame.fromUciMoves(moves).pgn();
    } catch {
      /* keep empty */
    }
    return db.tx(async (q) => {
      const change: Partial<Record<Color, { before: number; after: number }>> = {};
      await q.query(
        `INSERT INTO games (id, white, black, time_control, rated, vs_bot, result, reason, moves, pgn, started_at, ended_at)
         VALUES ($1,$2,$3,$4,$5,false,$6,$7,$8,$9,to_timestamp($10 / 1000.0),to_timestamp($11 / 1000.0))`,
        [g.id, g.white, g.black, g.tc, rated, result, reason, moves.join(' '), pgn, g.startedAt, now],
      );
      if (rated) {
        const rw = await ratingOf(q, g.white, cat);
        const rb = await ratingOf(q, g.black, cat);
        const score = result === '1-0' ? 1 : result === '0-1' ? 0 : 0.5;
        const next = rateGame(rw, rb, score);
        for (const [u, rt] of [
          [g.white, next.white],
          [g.black, next.black],
        ] as const) {
          await q.query(
            `INSERT INTO ratings (user_id, category, rating, rd, volatility, games) VALUES ($1,$2,$3,$4,$5,1)
             ON CONFLICT (user_id, category) DO UPDATE SET rating = $3, rd = $4, volatility = $5, games = ratings.games + 1`,
            [u, cat, rt.rating, rt.rd, rt.vol],
          );
        }
        change.white = { before: Math.round(rw.rating), after: Math.round(next.white.rating) };
        change.black = { before: Math.round(rb.rating), after: Math.round(next.black.rating) };
      }
      if (reason !== 'aborted') {
        const col = (c: Color) => (result === '1/2-1/2' ? 'draws' : result === winResult(c) ? 'wins' : 'losses');
        for (const c of ['white', 'black'] as const) {
          await q.query(`UPDATE users SET ${col(c)} = ${col(c)} + 1 WHERE id = $1`, [userOf(g, c)]);
        }
      }
      if (reason === 'abandon') {
        const loser = result === '1-0' ? g.black : g.white;
        await q.query('UPDATE users SET abandons = abandons + 1 WHERE id = $1', [loser]);
      }
      return change;
    });
  }

  async function timeoutLocked(g: GameRec, flagged: Color) {
    const winner = other(flagged);
    if (flagged === 'white') g.clockW = 0;
    else g.clockB = 0;
    await r.hset(`game:${g.id}`, flagged === 'white' ? 'clockW' : 'clockB', '0');
    await endLocked(g, cannotMate(g.fen, winner) ? '1/2-1/2' : winResult(winner), 'timeout');
  }

  // ---------- actions ----------

  async function onAction(userId: string, m: GameAction): Promise<Out | null> {
    return withLock(lockKey(m.gameId), async () => {
      const g = await load(m.gameId);
      const color = g ? colorOf(g, userId) : null;
      if (!g || !color) return errorMsg('no_game', 'No such game for you');

      if (m.type === 'game:sync') return stateMsg(g, userId);
      if (g.status !== 'active') {
        await sendState(g, userId);
        return errorMsg('game_over', 'The game has ended');
      }
      const opponent = userOf(g, other(color));

      switch (m.type) {
        case 'game:move':
          return applyMove(g, color, userId, m.uci, m.ply);
        case 'game:resign':
          await endLocked(g, winResult(other(color)), 'resign');
          return null;
        case 'game:drawOffer':
          if (g.drawOffer === other(color)) {
            await endLocked(g, '1/2-1/2', 'draw-agreed');
            return null;
          }
          if (g.drawOffer !== color) {
            await r.hset(`game:${g.id}`, 'drawOffer', color);
            await toUser(opponent, msg('game:drawOffer', { gameId: g.id, from: color }));
          }
          return null;
        case 'game:drawRespond':
          if (g.drawOffer !== other(color)) return errorMsg('no_draw_offer', 'No draw offer to answer');
          if (m.accept) {
            await endLocked(g, '1/2-1/2', 'draw-agreed');
          } else {
            await r.hset(`game:${g.id}`, 'drawOffer', '');
            await toUser(opponent, msg('game:drawDeclined', { gameId: g.id }));
          }
          return null;
        case 'game:claimVictory':
          if (g.abandoned !== other(color)) return errorMsg('cannot_claim', 'Opponent has not abandoned');
          await endLocked(g, winResult(color), 'abandon');
          return null;
      }
      return null;
    });
  }

  async function applyMove(g: GameRec, color: Color, userId: string, uci: unknown, ply: unknown): Promise<Out | null> {
    if (typeof uci !== 'string' || typeof ply !== 'number') return errorMsg('bad_message', 'uci and ply required');
    const moves = await r.lrange(`game:${g.id}:moves`, 0, -1);
    if (ply < g.ply) {
      // Stale: resent after a reconnect, or the client is behind. Never an error; resync if it differs.
      if (moves[ply] !== uci) await sendState(g, userId);
      return null;
    }
    if (ply !== g.ply) {
      await sendState(g, userId);
      return errorMsg('bad_ply', `Expected ply ${g.ply}`);
    }
    if (g.turn !== color) {
      await sendState(g, userId);
      return errorMsg('not_your_turn', 'Wait for your turn');
    }
    const game = ChessGame.fromUciMoves(moves);
    if (!game.move(uci)) {
      await sendState(g, userId);
      return errorMsg('illegal_move', `Illegal move ${uci}`);
    }

    const now = Date.now();
    const clocks = { white: g.clockW, black: g.clockB };
    if (g.ply >= 2) {
      const left = clocks[color] - (now - g.lastMoveAt);
      if (left <= 0) {
        await timeoutLocked(g, color);
        return null;
      }
      clocks[color] = left + g.inc;
    }
    const newPly = g.ply + 1;
    const turn = other(color);
    const status = game.status();

    const tx = r.multi();
    tx.hset(`game:${g.id}`, {
      fen: game.fen,
      ply: String(newPly),
      turn,
      clockW: String(clocks.white),
      clockB: String(clocks.black),
      lastMoveAt: String(now),
      drawOffer: '',
    });
    tx.rpush(`game:${g.id}:moves`, uci);
    if (newPly === 1) tx.zadd('timers', now + d.abortMs, `${g.id}:abort`); // black's first move now on the clock
    if (newPly === 2) tx.zrem('timers', `${g.id}:abort`);
    if (newPly >= 2 && !status.over) tx.zadd('timers', now + clocks[turn], `${g.id}:flag`);
    await tx.exec();

    Object.assign(g, { fen: game.fen, ply: newPly, turn, clockW: clocks.white, clockB: clocks.black, lastMoveAt: now });
    await toGame(g, msg('game:move', { gameId: g.id, uci, fen: game.fen, ply: newPly, clocks, serverTime: now }));
    if (status.over) await endLocked(g, status.result!, status.reason!);
    return null;
  }

  // ---------- timers ----------

  /** A due game timer: "flag", "abort" or "grace" (with the colour that left). */
  async function onTimer(id: string, kind: string, color: Color | undefined, member: string) {
    await withLock(lockKey(id), async () => {
      const g = await load(id);
      if (!g || g.status !== 'active') return;
      if (kind === 'flag') {
        if (g.ply < 2) return;
        const left = (g.turn === 'white' ? g.clockW : g.clockB) - (Date.now() - g.lastMoveAt);
        if (left > 0) {
          await r.zadd('timers', Date.now() + left, member);
          return;
        }
        await timeoutLocked(g, g.turn);
      } else if (kind === 'abort') {
        if (g.ply < 2) await endLocked(g, '1/2-1/2', 'aborted');
      } else if (kind === 'grace' && color) {
        if (await ctx.isConnected(userOf(g, color))) return; // came back
        await r.hset(`game:${id}`, 'abandoned', color);
        await toUser(userOf(g, other(color)), msg('opponent:abandoned', { gameId: id }));
      }
    });
  }

  // ---------- connections ----------

  /** After auth: resume the user's game if one is running. */
  async function onConnect(conn: Conn, userId: string) {
    const gameId = await r.get(`user:${userId}:game`);
    if (!gameId) return;
    await withLock(lockKey(gameId), async () => {
      const g = await load(gameId);
      const color = g ? colorOf(g, userId) : null;
      if (!g || !color || g.status !== 'active') return;
      const hadGrace = (await r.zrem('timers', `${g.id}:grace:${color}`)) === 1;
      if (hadGrace || g.abandoned === color) {
        await r.hset(`game:${g.id}`, 'abandoned', '');
        await toUser(userOf(g, other(color)), msg('opponent:reconnected', { gameId: g.id }));
      }
      ctx.sendConn(conn, await stateMsg(g, userId));
    });
  }

  /** The user's last socket closed: start the grace period. */
  async function onDisconnect(userId: string) {
    const gameId = await r.get(`user:${userId}:game`);
    if (!gameId) return;
    await withLock(lockKey(gameId), async () => {
      const g = await load(gameId);
      const color = g ? colorOf(g, userId) : null;
      if (!g || !color || g.status !== 'active') return;
      const graceMs = parseTimeControl(g.tc).initialMs <= 5 * 60_000 ? d.graceShortMs : d.graceLongMs;
      await r.zadd('timers', Date.now() + graceMs, `${g.id}:grace:${color}`);
      await toUser(userOf(g, other(color)), msg('opponent:disconnected', { gameId: g.id, graceMs }));
    });
  }

  const inGame = async (userId: string) => Boolean(await r.get(`user:${userId}:game`));

  return { create, onAction, onTimer, onConnect, onDisconnect, inGame };
}
