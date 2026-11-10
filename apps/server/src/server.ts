import type { AddressInfo } from 'node:net';

import { WebSocketServer } from 'ws';

import { createChallenges } from './challenges.ts';
import { defaultDelays, defaultTimeControls, type Delays } from './config.ts';
import { createCtx, errorMsg, type Conn, type Out } from './context.ts';
import { openDb, type Db } from './db.ts';
import { createGames } from './games.ts';
import { createHttp } from './http.ts';
import { createLobby } from './lobby.ts';
import { createQueue } from './queue.ts';
import { connectRedis, type RedisPair } from './redis.ts';
import { createRouter } from './router.ts';
import { createTimers } from './timers.ts';
import { createUsers } from './users.ts';

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

/** Wires the modules together and starts HTTP + WebSocket on one port. */
export async function startServer(opts: ServerOptions = {}): Promise<RunningServer> {
  const log = opts.log ?? ((m: string) => console.log(`[server] ${m}`));
  const d: Delays = { ...defaultDelays, ...opts.delays };
  const secret = opts.tokenSecret ?? process.env.TOKEN_SECRET ?? DEV_SECRET;
  if (secret === DEV_SECRET) log('TOKEN_SECRET not set: using the dev secret (never in production)');

  const redis = connectRedis(opts.redisUrl, opts.mockRedisKey ?? 'shaxmat-dev', log);
  const ownDb = !opts.db;
  const db = opts.db ?? (await openDb(opts.databaseUrl, log));
  const ctx = createCtx({ redis, db, d, timeControls: opts.timeControls ?? defaultTimeControls, log });

  const users = createUsers(ctx);
  const lobby = createLobby(ctx, users);
  const games = createGames(ctx, lobby);
  const queue = createQueue(ctx, users, games, lobby);
  const challenges = createChallenges(ctx, users, games, lobby, queue);
  const timerTick = createTimers(ctx, games, challenges);
  const router = createRouter(ctx, secret, { users, lobby, games, queue, challenges });

  // Messages for a user or a game reach whichever instance holds their sockets.
  await redis.sub.psubscribe('user:*', 'game:*', 'lobby');
  redis.sub.on('pmessage', (_pattern: string, channel: string, raw: string) => {
    try {
      if (channel === 'lobby') {
        lobby.markDirty();
      } else if (channel.startsWith('user:')) {
        ctx.deliver(channel.slice(5), JSON.parse(raw));
      } else {
        const { white, black, m } = JSON.parse(raw) as { white: string; black: string; m: Out };
        ctx.deliver(white, m);
        ctx.deliver(black, m);
      }
    } catch (e) {
      log(`bad pubsub payload on ${channel}: ${e}`);
    }
  });

  const http = createHttp(users, log);
  const wss = new WebSocketServer({ server: http, maxPayload: 512 * 1024 });
  wss.on('connection', (ws) => {
    const conn: Conn = { ws };
    // Messages from one socket are handled in order.
    let chain = Promise.resolve();
    ws.on('message', (data) => {
      chain = chain.then(async () => {
        try {
          const reply = await router.onMessage(conn, data.toString());
          if (reply) ctx.sendConn(conn, reply);
        } catch (e) {
          log(`handler error: ${e}`);
          ctx.sendConn(conn, errorMsg('internal', 'Server error'));
        }
      });
    });
    ws.on('close', () => {
      chain = chain.then(() => router.onClose(conn)).catch((e) => log(`close error: ${e}`));
    });
  });

  /** setInterval that never overlaps itself. */
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
    loop(queue.tick, d.matchTickMs),
    loop(timerTick, d.timerTickMs),
    loop(lobby.heartbeat, d.statsEveryMs),
    loop(lobby.pushIfDirty, d.lobbyPushMs),
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
