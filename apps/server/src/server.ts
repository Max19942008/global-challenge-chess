import { randomBytes, randomUUID } from 'node:crypto';
import { createServer as createHttpServer, type Server as HttpServer } from 'node:http';
import type { AddressInfo } from 'node:net';

import {
  ChessGame,
  PROTOCOL_VERSION,
  parseTimeControl,
  type ClientMessage,
  type Clocks,
  type Color,
  type EndReason,
  type PlayerInfo,
  type RatingCategory,
  type Result,
  type ServerMessage,
  type UserInfo,
} from '@shaxmat/chess-core';
import { WebSocketServer, type WebSocket } from 'ws';

import { signToken, verifyToken } from './auth.ts';
import { categories, categoryOf, defaultDelays, defaultTimeControls, type Delays } from './config.ts';
import { openDb, type Db } from './db.ts';
import { connectRedis, type RedisPair } from './redis.ts';
import { DEFAULT_RATING, isProvisional, rateGame, type Rating } from './rating.ts';

export interface ServerOptions {
  /** 0 = pick a free port. Default 8080. */
  port?: number;
  redisUrl?: string;
  /** Isolates ioredis-mock state; instances with the same key share it (as if on one Redis). */
  mockRedisKey?: string;
  /** Share one database between instances (tests). Otherwise opened from databaseUrl / PGlite. */
  db?: Db;
  databaseUrl?: string;
  tokenSecret?: string;
  timeControls?: string[];
  delays?: Partial<Delays>;
  log?: (msg: string) => void;
}

export interface RunningServer {
  port: number;
  url: string;
  db: Db;
  redis: RedisPair;
  close(): Promise<void>;
}

const DEV_SECRET = 'dev-only-secret-change-me';

type Out = ServerMessage;
type OutOf<T extends Out['type']> = Omit<Extract<Out, { type: T }>, 'v' | 'type'>;
const msg = <T extends Out['type']>(type: T, payload: OutOf<T>): Out => ({ v: PROTOCOL_VERSION, type, ...payload }) as Out;

interface Conn {
  ws: WebSocket;
  userId?: string;
}

interface QueueEntry {
  userId: string;
  name: string;
  tc: string;
  rated: boolean;
  rating: number;
  provisional: boolean;
  at: number;
  key: string;
}

/** Game as stored in the Redis hash game:{id}. */
interface GameRec {
  id: string;
  white: string;
  black: string;
  whiteName: string;
  blackName: string;
  whiteRating: number;
  blackRating: number;
  whiteProv: boolean;
  blackProv: boolean;
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

const other = (c: Color): Color => (c === 'white' ? 'black' : 'white');
const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

export async function startServer(opts: ServerOptions = {}): Promise<RunningServer> {
  const log = opts.log ?? ((m: string) => console.log(`[server] ${m}`));
  const d: Delays = { ...defaultDelays, ...opts.delays };
  const timeControls = opts.timeControls ?? defaultTimeControls;
  const secret = opts.tokenSecret ?? process.env.TOKEN_SECRET ?? DEV_SECRET;
  if (secret === DEV_SECRET) log('TOKEN_SECRET not set: using the dev secret (never in production)');

  const redis = connectRedis(opts.redisUrl, opts.mockRedisKey ?? 'shaxmat-dev', log);
  const r = redis.cmd;
  const ownDb = !opts.db;
  const db = opts.db ?? (await openDb(opts.databaseUrl, log));

  const local = new Map<string, Set<Conn>>(); // userId -> this instance's sockets
  const lastWaitingSent = new Map<string, number>();

  // ---------- delivery ----------

  const sendConn = (c: Conn, m: Out) => {
    if (c.ws.readyState === c.ws.OPEN) c.ws.send(JSON.stringify(m));
  };
  const deliver = (userId: string, m: Out) => {
    for (const c of local.get(userId) ?? []) sendConn(c, m);
  };
  /** Reaches the user on whichever instance they're connected to. */
  const toUser = (userId: string, m: Out) => r.publish(`user:${userId}`, JSON.stringify(m));
  /** Moves etc. go through the game channel; every instance forwards to its own sockets. */
  const toGame = (g: { id: string; white: string; black: string }, m: Out) =>
    r.publish(`game:${g.id}`, JSON.stringify({ white: g.white, black: g.black, m }));

  await redis.sub.psubscribe('user:*', 'game:*');
  redis.sub.on('pmessage', (_pattern: string, channel: string, raw: string) => {
    try {
      if (channel.startsWith('user:')) {
        deliver(channel.slice(5), JSON.parse(raw));
      } else {
        const { white, black, m } = JSON.parse(raw) as { white: string; black: string; m: Out };
        deliver(white, m);
        deliver(black, m);
      }
    } catch (e) {
      log(`bad pubsub payload on ${channel}: ${e}`);
    }
  });

  // ---------- locking ----------

  async function withLock<T>(key: string, fn: () => Promise<T>): Promise<T> {
    const token = randomUUID();
    for (let i = 0; ; i++) {
      if ((await r.set(key, token, 'PX', 3000, 'NX')) === 'OK') break;
      if (i > 150) throw new Error(`lock timeout ${key}`);
      await sleep(10);
    }
    try {
      return await fn();
    } finally {
      if ((await r.get(key)) === token) await r.del(key);
    }
  }

  // ---------- users & ratings ----------

  async function getRating(userId: string, cat: RatingCategory): Promise<Rating> {
    const rows = await db.query<{ rating: number; rd: number; volatility: number }>(
      'SELECT rating, rd, volatility FROM ratings WHERE user_id = $1 AND category = $2',
      [userId, cat],
    );
    const row = rows[0];
    return row ? { rating: row.rating, rd: row.rd, vol: row.volatility } : { ...DEFAULT_RATING };
  }

  async function userInfo(userId: string): Promise<UserInfo | null> {
    const users = await db.query<{ name: string }>('SELECT name FROM users WHERE id = $1', [userId]);
    if (!users[0]) return null;
    const ratings = {} as UserInfo['ratings'];
    for (const cat of categories) {
      const rt = await getRating(userId, cat);
      ratings[cat] = { rating: Math.round(rt.rating), provisional: isProvisional(rt) };
    }
    return { id: userId, name: users[0].name, ratings };
  }

  // ---------- games in Redis ----------

  async function loadGame(id: string): Promise<GameRec | null> {
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

  /** Remaining time as of `now`. Clocks run only from ply 2 (each side's first move is free, guarded by the abort timer). */
  function clocksAt(g: GameRec, now: number): Clocks {
    const c = { white: g.clockW, black: g.clockB };
    if (g.status === 'active' && g.ply >= 2) c[g.turn] = Math.max(0, c[g.turn] - (now - g.lastMoveAt));
    return c;
  }

  const playerInfo = (g: GameRec, c: Color): PlayerInfo =>
    c === 'white'
      ? { id: g.white, name: g.whiteName, rating: g.whiteRating, provisional: g.whiteProv }
      : { id: g.black, name: g.blackName, rating: g.blackRating, provisional: g.blackProv };

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

  async function sendState(g: GameRec, userId: string) {
    await toUser(userId, await stateMsg(g, userId));
  }

  /** Winner-side check for timeouts: a lone king, or king + one minor piece, cannot mate. */
  function cannotMate(fen: string, side: Color): boolean {
    const board = fen.split(' ')[0]!;
    const pieces = [...board].filter((ch) => (side === 'white' ? /[PNBRQ]/ : /[pnbrq]/).test(ch));
    return pieces.length === 0 || (pieces.length === 1 && /[nbNB]/.test(pieces[0]!));
  }

  /** Must be called holding the game lock. */
  async function endGameLocked(g: GameRec, result: Result, reason: EndReason) {
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

    const rated = g.rated && reason !== 'aborted';
    const cat = categoryOf(g.tc);
    let change: { white?: { before: number; after: number }; black?: { before: number; after: number } } = {};
    try {
      let pgn = '';
      try {
        pgn = ChessGame.fromUciMoves(moves).pgn();
      } catch {
        /* keep empty */
      }
      await db.tx(async (q) => {
        await q.query(
          `INSERT INTO games (id, white, black, time_control, rated, vs_bot, result, reason, moves, pgn, started_at, ended_at)
           VALUES ($1,$2,$3,$4,$5,false,$6,$7,$8,$9,to_timestamp($10 / 1000.0),to_timestamp($11 / 1000.0))`,
          [g.id, g.white, g.black, g.tc, rated, result, reason, moves.join(' '), pgn, g.startedAt, now],
        );
        if (rated) {
          const rw = await getRatingTx(q, g.white, cat);
          const rb = await getRatingTx(q, g.black, cat);
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
          change = {
            white: { before: Math.round(rw.rating), after: Math.round(next.white.rating) },
            black: { before: Math.round(rb.rating), after: Math.round(next.black.rating) },
          };
        }
        if (reason === 'abandon') {
          const loser = result === '1-0' ? g.black : g.white;
          await q.query('UPDATE users SET abandons = abandons + 1 WHERE id = $1', [loser]);
        }
      });
    } catch (e) {
      log(`saving game ${g.id} failed: ${e}`);
    }

    for (const c of ['white', 'black'] as const) {
      const ratingChange = change[c];
      await toUser(
        c === 'white' ? g.white : g.black,
        msg('game:end', { gameId: g.id, result, reason, ...(ratingChange ? { ratingChange } : {}) }),
      );
    }
  }

  async function getRatingTx(q: Db | { query: Db['query'] }, userId: string, cat: RatingCategory): Promise<Rating> {
    const rows = await q.query<{ rating: number; rd: number; volatility: number }>(
      'SELECT rating, rd, volatility FROM ratings WHERE user_id = $1 AND category = $2',
      [userId, cat],
    );
    const row = rows[0];
    return row ? { rating: row.rating, rd: row.rd, vol: row.volatility } : { ...DEFAULT_RATING };
  }

  const winResult = (winner: Color): Result => (winner === 'white' ? '1-0' : '0-1');

  async function timeoutLocked(g: GameRec, flagged: Color) {
    const winner = other(flagged);
    if (flagged === 'white') g.clockW = 0;
    else g.clockB = 0;
    await r.hset(`game:${g.id}`, flagged === 'white' ? 'clockW' : 'clockB', '0');
    await endGameLocked(g, cannotMate(g.fen, winner) ? '1/2-1/2' : winResult(winner), 'timeout');
  }

  async function createGame(a: QueueEntry, b: QueueEntry) {
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
          opponent: { id: opp.userId, name: opp.name, rating: Math.round(opp.rating), provisional: opp.provisional },
          timeControl: a.tc,
          rated: a.rated,
          fen,
          clocks,
          serverTime: now,
        }),
      );
    }
    log(`game ${id}: ${w.name} vs ${bl.name} ${a.tc}${a.rated ? ' rated' : ''}`);
  }

  // ---------- queue ----------

  const queueKey = (tc: string, rated: boolean) => `queue:${tc}:${rated ? 'rated' : 'casual'}`;

  async function onlineCount(): Promise<number> {
    const now = Date.now();
    await r.zremrangebyscore('online', 0, now - 3 * d.statsEveryMs);
    return r.zcard('online');
  }

  async function leaveQueue(userId: string): Promise<boolean> {
    const raw = await r.hget('queue:joined', userId);
    if (!raw) return false;
    const e = JSON.parse(raw) as QueueEntry;
    await r.zrem(e.key, userId);
    await r.hdel('queue:joined', userId);
    await r.hdel('queue:bot', userId);
    lastWaitingSent.delete(userId);
    return true;
  }

  async function joinQueue(userId: string, tc: string, rated: boolean): Promise<Out | null> {
    if (!timeControls.includes(tc)) return msg('error', { code: 'unknown_time_control', message: `Allowed: ${timeControls.join(', ')}` });
    if (await r.get(`user:${userId}:game`)) return msg('error', { code: 'already_in_game', message: 'Finish or sync your current game first' });
    await leaveQueue(userId);
    const info = await userInfo(userId);
    if (!info) return msg('error', { code: 'unauthenticated', message: 'Unknown user' });
    const rt = await getRating(userId, categoryOf(tc));
    const entry: QueueEntry = {
      userId,
      name: info.name,
      tc,
      rated,
      rating: rt.rating,
      provisional: isProvisional(rt),
      at: Date.now(),
      key: queueKey(tc, rated),
    };
    await r.zadd(entry.key, entry.rating, userId);
    await r.hset('queue:joined', userId, JSON.stringify(entry));
    await r.hdel('queue:bot', userId);
    lastWaitingSent.set(userId, Date.now());
    return msg('queue:waiting', { elapsedMs: 0, onlineCount: await onlineCount() });
  }

  function windowFor(e: QueueEntry, now: number): number {
    const waited = now - e.at;
    const [t1, t2, t3] = d.windowAfterMs;
    const [r1, r2, r3] = d.windowRange;
    if (waited < t1) return r1;
    if (waited < t2) return r2;
    if (waited < t3) return r3;
    return Infinity;
  }

  async function matchTick() {
    if ((await r.set('lock:match', '1', 'PX', 2000, 'NX')) !== 'OK') return;
    try {
      const all = Object.values(await r.hgetall('queue:joined')).map((s) => JSON.parse(s) as QueueEntry);
      const now = Date.now();
      const used = new Set<string>();
      const byKey = new Map<string, QueueEntry[]>();
      for (const e of all) byKey.set(e.key, [...(byKey.get(e.key) ?? []), e]);

      for (const list of byKey.values()) {
        list.sort((a, b) => a.at - b.at);
        for (const p of list) {
          if (used.has(p.userId)) continue;
          let best: QueueEntry | null = null;
          for (const q of list) {
            if (q.userId === p.userId || used.has(q.userId)) continue;
            const diff = Math.abs(q.rating - p.rating);
            if (diff > Math.max(windowFor(p, now), windowFor(q, now))) continue;
            if (!best || diff < Math.abs(best.rating - p.rating)) best = q;
          }
          if (!best) continue;
          // ZREM is atomic per member: whoever removes a player (us, or a concurrent queue:leave) owns them.
          const gotP = await r.zrem(p.key, p.userId);
          const gotQ = await r.zrem(best.key, best.userId);
          if (gotP !== 1 || gotQ !== 1) {
            if (gotP === 1) await r.zadd(p.key, p.rating, p.userId);
            if (gotQ === 1) await r.zadd(best.key, best.rating, best.userId);
            continue;
          }
          await r.hdel('queue:joined', p.userId, best.userId);
          await r.hdel('queue:bot', p.userId, best.userId);
          used.add(p.userId).add(best.userId);
          lastWaitingSent.delete(p.userId);
          lastWaitingSent.delete(best.userId);
          await createGame(p, best);
        }
      }

      const count = all.length - used.size > 0 ? await onlineCount() : 0;
      for (const e of all) {
        if (used.has(e.userId)) continue;
        const waited = now - e.at;
        if (waited >= d.botOfferMs && !(await r.hget('queue:bot', e.userId))) {
          await r.hset('queue:bot', e.userId, 'offered');
          await toUser(e.userId, msg('queue:botOffer', { suggestedElo: Math.round(e.rating) }));
        }
        if (now - (lastWaitingSent.get(e.userId) ?? 0) >= d.waitingEveryMs) {
          lastWaitingSent.set(e.userId, now);
          await toUser(e.userId, msg('queue:waiting', { elapsedMs: waited, onlineCount: count }));
        }
      }
    } finally {
      await r.del('lock:match');
    }
  }

  // ---------- timers ----------

  async function timerTick() {
    const now = Date.now();
    const due = await r.zrangebyscore('timers', 0, now);
    for (const member of due) {
      if ((await r.zrem('timers', member)) !== 1) continue; // another instance took it
      const [id, kind, color] = member.split(':') as [string, string, Color | undefined];
      try {
        await withLock(`lock:game:${id}`, async () => {
          const g = await loadGame(id);
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
            if (g.ply < 2) await endGameLocked(g, '1/2-1/2', 'aborted');
          } else if (kind === 'grace' && color) {
            const userId = color === 'white' ? g.white : g.black;
            if (Number((await r.hget('conns', userId)) ?? 0) > 0) return; // came back
            await r.hset(`game:${id}`, 'abandoned', color);
            await toUser(color === 'white' ? g.black : g.white, msg('opponent:abandoned', { gameId: id }));
          }
        });
      } catch (e) {
        log(`timer ${member} failed: ${e}`);
      }
    }
  }

  // ---------- game actions ----------

  async function onGameAction(userId: string, m: Extract<ClientMessage, { gameId: string }>): Promise<Out | null> {
    return withLock(`lock:game:${m.gameId}`, async () => {
      const g = await loadGame(m.gameId);
      const color = g ? colorOf(g, userId) : null;
      if (!g || !color) return msg('error', { code: 'no_game', message: 'No such game for you' });

      if (m.type === 'game:sync') return stateMsg(g, userId);
      if (g.status !== 'active') {
        await sendState(g, userId);
        return msg('error', { code: 'game_over', message: 'The game has ended' });
      }

      switch (m.type) {
        case 'game:move':
          return applyMove(g, color, userId, m.uci, m.ply);
        case 'game:resign':
          await endGameLocked(g, winResult(other(color)), 'resign');
          return null;
        case 'game:drawOffer':
          if (g.drawOffer === other(color)) {
            await endGameLocked(g, '1/2-1/2', 'draw-agreed');
            return null;
          }
          if (g.drawOffer !== color) {
            await r.hset(`game:${g.id}`, 'drawOffer', color);
            await toUser(color === 'white' ? g.black : g.white, msg('game:drawOffer', { gameId: g.id, from: color }));
          }
          return null;
        case 'game:drawRespond':
          if (g.drawOffer !== other(color)) return msg('error', { code: 'no_draw_offer', message: 'No draw offer to answer' });
          if (m.accept) {
            await endGameLocked(g, '1/2-1/2', 'draw-agreed');
          } else {
            await r.hset(`game:${g.id}`, 'drawOffer', '');
            await toUser(color === 'white' ? g.black : g.white, msg('game:drawDeclined', { gameId: g.id }));
          }
          return null;
        case 'game:claimVictory':
          if (g.abandoned !== other(color)) return msg('error', { code: 'cannot_claim', message: 'Opponent has not abandoned' });
          await endGameLocked(g, winResult(color), 'abandon');
          return null;
      }
      return null;
    });
  }

  async function applyMove(g: GameRec, color: Color, userId: string, uci: unknown, ply: unknown): Promise<Out | null> {
    if (typeof uci !== 'string' || typeof ply !== 'number') return msg('error', { code: 'bad_message', message: 'uci and ply required' });
    const moves = await r.lrange(`game:${g.id}:moves`, 0, -1);
    if (ply < g.ply) {
      // Stale: resent after a reconnect, or the client is behind. Never an error; resync if it differs.
      if (moves[ply] !== uci) await sendState(g, userId);
      return null;
    }
    if (ply !== g.ply) {
      await sendState(g, userId);
      return msg('error', { code: 'bad_ply', message: `Expected ply ${g.ply}` });
    }
    if (g.turn !== color) {
      await sendState(g, userId);
      return msg('error', { code: 'not_your_turn', message: 'Wait for your turn' });
    }
    const game = ChessGame.fromUciMoves(moves);
    if (!game.move(uci)) {
      await sendState(g, userId);
      return msg('error', { code: 'illegal_move', message: `Illegal move ${uci}` });
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
    if (status.over) await endGameLocked(g, status.result!, status.reason!);
    return null;
  }

  // ---------- connections ----------

  async function onAuthed(conn: Conn, userId: string, token: string) {
    conn.userId = userId;
    let set = local.get(userId);
    if (!set) local.set(userId, (set = new Set()));
    set.add(conn);
    await r.hincrby('conns', userId, 1);
    await r.zadd('online', Date.now(), userId);

    const info = await userInfo(userId);
    sendConn(conn, msg('auth:ok', { token, user: info! }));
    sendConn(conn, msg('lobby:stats', { onlineCount: await onlineCount() }));

    const gameId = await r.get(`user:${userId}:game`);
    if (!gameId) return;
    await withLock(`lock:game:${gameId}`, async () => {
      const g = await loadGame(gameId);
      const color = g ? colorOf(g, userId) : null;
      if (!g || !color || g.status !== 'active') return;
      const hadGrace = (await r.zrem('timers', `${g.id}:grace:${color}`)) === 1;
      if (hadGrace || g.abandoned === color) {
        await r.hset(`game:${g.id}`, 'abandoned', '');
        await toUser(color === 'white' ? g.black : g.white, msg('opponent:reconnected', { gameId: g.id }));
      }
      sendConn(conn, await stateMsg(g, userId));
    });
  }

  async function onClose(conn: Conn) {
    const userId = conn.userId;
    if (!userId) return;
    local.get(userId)?.delete(conn);
    if (local.get(userId)?.size === 0) local.delete(userId);
    const left = await r.hincrby('conns', userId, -1);
    if (left > 0) return;
    await r.hdel('conns', userId);
    await leaveQueue(userId);
    const gameId = await r.get(`user:${userId}:game`);
    if (!gameId) return;
    await withLock(`lock:game:${gameId}`, async () => {
      const g = await loadGame(gameId);
      const color = g ? colorOf(g, userId) : null;
      if (!g || !color || g.status !== 'active') return;
      const graceMs = parseTimeControl(g.tc).initialMs <= 5 * 60_000 ? d.graceShortMs : d.graceLongMs;
      await r.zadd('timers', Date.now() + graceMs, `${g.id}:grace:${color}`);
      await toUser(color === 'white' ? g.black : g.white, msg('opponent:disconnected', { gameId: g.id, graceMs }));
    });
  }

  async function onMessage(conn: Conn, raw: string): Promise<Out | null> {
    let m: ClientMessage;
    try {
      m = JSON.parse(raw);
    } catch {
      return msg('error', { code: 'bad_message', message: 'Not JSON' });
    }
    if (!m || typeof m !== 'object' || typeof m.type !== 'string') return msg('error', { code: 'bad_message', message: 'Missing type' });
    if (m.v !== PROTOCOL_VERSION) return msg('error', { code: 'unsupported_version', message: `Server speaks v${PROTOCOL_VERSION}` });

    if (m.type === 'ping') return msg('pong', { t: m.t, serverTime: Date.now() });
    if (m.type === 'auth:guest') {
      const userId = randomUUID();
      const name =
        typeof m.name === 'string' && m.name.trim() ? m.name.trim().slice(0, 24) : `Guest-${1000 + Math.floor(Math.random() * 9000)}`;
      await db.query('INSERT INTO users (id, name) VALUES ($1, $2)', [userId, name]);
      await onAuthed(conn, userId, signToken(secret, userId));
      return null;
    }
    if (m.type === 'auth') {
      const userId = verifyToken(secret, m.token);
      const exists = userId && (await db.query('SELECT 1 FROM users WHERE id = $1', [userId])).length > 0;
      if (!userId || !exists) return msg('error', { code: 'invalid_token', message: 'Unknown or invalid token' });
      if (conn.userId && conn.userId !== userId) return msg('error', { code: 'bad_message', message: 'Already authenticated' });
      if (!conn.userId) await onAuthed(conn, userId, m.token);
      return null;
    }

    const userId = conn.userId;
    if (!userId) return msg('error', { code: 'unauthenticated', message: 'Send auth or auth:guest first' });

    switch (m.type) {
      case 'queue:join':
        return joinQueue(userId, m.timeControl, m.rated !== false);
      case 'queue:leave':
        await leaveQueue(userId);
        return msg('queue:left', {});
      case 'queue:botAccept':
        await leaveQueue(userId);
        return msg('queue:left', {});
      case 'queue:botDecline':
        if (await r.hget('queue:joined', userId)) await r.hset('queue:bot', userId, 'declined');
        return null;
      case 'game:move':
      case 'game:resign':
      case 'game:drawOffer':
      case 'game:drawRespond':
      case 'game:sync':
      case 'game:claimVictory':
        if (typeof m.gameId !== 'string') return msg('error', { code: 'bad_message', message: 'gameId required' });
        return onGameAction(userId, m);
      default:
        return msg('error', { code: 'bad_message', message: `Unknown type ${(m as { type: string }).type}` });
    }
  }

  // ---------- servers & loops ----------

  const http: HttpServer = createHttpServer((req, res) => {
    if (req.url === '/health') {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true, protocol: PROTOCOL_VERSION }));
      return;
    }
    res.writeHead(404).end();
  });
  const wss = new WebSocketServer({ server: http });
  wss.on('connection', (ws) => {
    const conn: Conn = { ws };
    // Messages from one socket are handled in order.
    let chain = Promise.resolve();
    ws.on('message', (data) => {
      chain = chain.then(async () => {
        try {
          const reply = await onMessage(conn, data.toString());
          if (reply) sendConn(conn, reply);
        } catch (e) {
          log(`handler error: ${e}`);
          sendConn(conn, msg('error', { code: 'internal', message: 'Server error' }));
        }
      });
    });
    ws.on('close', () => {
      chain = chain.then(() => onClose(conn)).catch((e) => log(`close error: ${e}`));
    });
  });

  const loop = (fn: () => Promise<void>, ms: number) => {
    let busy = false;
    return setInterval(async () => {
      if (busy) return;
      busy = true;
      try {
        await fn();
      } catch (e) {
        log(`loop error: ${e}`);
      } finally {
        busy = false;
      }
    }, ms);
  };
  const intervals = [
    loop(matchTick, d.matchTickMs),
    loop(timerTick, d.timerTickMs),
    loop(async () => {
      const now = Date.now();
      for (const userId of local.keys()) await r.zadd('online', now, userId);
      const count = await onlineCount();
      for (const conns of local.values()) for (const c of conns) sendConn(c, msg('lobby:stats', { onlineCount: count }));
    }, d.statsEveryMs),
  ];

  await new Promise<void>((resolve) => http.listen(opts.port ?? 8080, resolve));
  const port = (http.address() as AddressInfo).port;
  log(`listening on ws://localhost:${port} (health: http://localhost:${port}/health)`);

  return {
    port,
    url: `ws://localhost:${port}`,
    db,
    redis,
    async close() {
      intervals.forEach(clearInterval);
      for (const c of wss.clients) c.terminate();
      await new Promise<void>((res) => wss.close(() => res()));
      await new Promise<void>((res) => http.close(() => res()));
      redis.sub.disconnect();
      redis.cmd.disconnect();
      if (ownDb) await db.close();
    },
  };
}
