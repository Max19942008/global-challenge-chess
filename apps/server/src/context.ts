import { randomUUID } from 'node:crypto';

import { PROTOCOL_VERSION, type ServerMessage } from '@shaxmat/chess-core';
import type { WebSocket } from 'ws';

import type { Delays } from './config.ts';
import type { Db } from './db.ts';
import type { RedisPair } from './redis.ts';

export type Out = ServerMessage;
type OutOf<T extends Out['type']> = Omit<Extract<Out, { type: T }>, 'v' | 'type'>;

/** A server message with the protocol version filled in. */
export const msg = <T extends Out['type']>(type: T, payload: OutOf<T>): Out =>
  ({ v: PROTOCOL_VERSION, type, ...payload }) as Out;

export const errorMsg = (code: string, message: string) => msg('error', { code, message });

export const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

/** One WebSocket on this instance. */
export interface Conn {
  ws: WebSocket;
  userId?: string;
  /** Receives lobby:players. */
  lobby?: boolean;
}

/** What every module needs: storage, timings and message delivery. */
export interface Ctx {
  r: RedisPair['cmd'];
  db: Db;
  d: Delays;
  timeControls: string[];
  log: (m: string) => void;
  /** userId -> this instance's sockets. */
  local: Map<string, Set<Conn>>;
  sendConn(c: Conn, m: Out): void;
  /** Delivers to this instance's sockets of the user (used by the pub/sub listener). */
  deliver(userId: string, m: Out): void;
  /** Reaches the user on whichever instance they're connected to. */
  toUser(userId: string, m: Out): Promise<unknown>;
  /** Moves etc. go through the game channel; every instance forwards to its own sockets. */
  toGame(g: { id: string; white: string; black: string }, m: Out): Promise<unknown>;
  withLock<T>(key: string, fn: () => Promise<T>): Promise<T>;
  /** Is the user connected to any instance? */
  isConnected(userId: string): Promise<boolean>;
}

export function createCtx(opts: Pick<Ctx, 'db' | 'd' | 'timeControls' | 'log'> & { redis: RedisPair }): Ctx {
  const r = opts.redis.cmd;
  const local = new Map<string, Set<Conn>>();

  const sendConn = (c: Conn, m: Out) => {
    if (c.ws.readyState === c.ws.OPEN) c.ws.send(JSON.stringify(m));
  };

  return {
    ...opts,
    r,
    local,
    sendConn,
    deliver(userId, m) {
      for (const c of local.get(userId) ?? []) sendConn(c, m);
    },
    toUser: (userId, m) => r.publish(`user:${userId}`, JSON.stringify(m)),
    toGame: (g, m) => r.publish(`game:${g.id}`, JSON.stringify({ white: g.white, black: g.black, m })),
    async withLock(key, fn) {
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
    },
    isConnected: async (userId) => Number((await r.hget('conns', userId)) ?? 0) > 0,
  };
}
