import type { LobbyPlayer, PresenceStatus } from '@shaxmat/chess-core';

import { msg, type Conn, type Ctx } from './context.ts';
import type { Users } from './users.ts';

/** The lobby list is capped; a huge list is no use on a phone. */
const MAX_LOBBY = 200;

const ORDER: Record<PresenceStatus, number> = { ready: 0, playing: 1, watching: 2 };

export type Lobby = ReturnType<typeof createLobby>;

/**
 * Who is online and what they're doing.
 * Redis: zset "online" (userId -> last heartbeat), hash "presence" (userId -> watching|ready).
 * "playing" is never stored: it is read from user:{id}:game.
 */
export function createLobby(ctx: Ctx, users: Users) {
  const { r, d } = ctx;
  let dirty = false;

  async function onlineCount(): Promise<number> {
    await r.zremrangebyscore('online', 0, Date.now() - 3 * d.statsEveryMs);
    return r.zcard('online');
  }

  /** Any instance: lobby lists everywhere need a refresh soon. */
  const changed = () => void r.publish('lobby', '1');
  const markDirty = () => (dirty = true);

  async function status(userId: string): Promise<PresenceStatus> {
    if (await r.get(`user:${userId}:game`)) return 'playing';
    return (await r.hget('presence', userId)) === 'ready' ? 'ready' : 'watching';
  }

  async function players(): Promise<LobbyPlayer[]> {
    await r.zremrangebyscore('online', 0, Date.now() - 3 * d.statsEveryMs);
    const ids = await r.zrange('online', 0, -1);
    if (ids.length === 0) return [];
    const [presence, games, infos] = await Promise.all([
      r.hmget('presence', ...ids),
      r.mget(...ids.map((id) => `user:${id}:game`)),
      users.infoMany(ids),
    ]);
    const list: LobbyPlayer[] = [];
    ids.forEach((id, i) => {
      const u = infos.get(id);
      if (!u) return;
      const st: PresenceStatus = games[i] ? 'playing' : presence[i] === 'ready' ? 'ready' : 'watching';
      list.push({ id, name: u.name, avatar: u.avatar, status: st, ratings: u.ratings, ...u.stats });
    });
    list.sort((a, b) => ORDER[a.status] - ORDER[b.status] || b.ratings.blitz.rating - a.ratings.blitz.rating);
    return list.slice(0, MAX_LOBBY);
  }

  const subscribers = () => [...ctx.local.values()].flatMap((set) => [...set].filter((c) => c.lobby));

  async function sendTo(conns: Conn[]) {
    if (conns.length === 0) return;
    const m = msg('lobby:players', { players: await players(), onlineCount: await onlineCount() });
    for (const c of conns) ctx.sendConn(c, m);
  }

  return {
    onlineCount,
    status,
    changed,
    markDirty,
    players,

    async subscribe(conn: Conn) {
      conn.lobby = true;
      await sendTo([conn]);
    },

    unsubscribe(conn: Conn) {
      conn.lobby = false;
    },

    async setStatus(userId: string, s: 'watching' | 'ready') {
      await r.hset('presence', userId, s);
      changed();
    },

    /** First socket of the user: online, "watching" unless they were already ready elsewhere. */
    async onConnect(userId: string) {
      await r.zadd('online', Date.now(), userId);
      await r.hsetnx('presence', userId, 'watching');
      changed();
    },

    /** Last socket of the user closed. */
    async onDisconnect(userId: string) {
      await r.zrem('online', userId);
      await r.hdel('presence', userId);
      changed();
    },

    /** Every statsEveryMs: heartbeats, the counter for everyone, the full list for subscribers. */
    async heartbeat() {
      const now = Date.now();
      for (const userId of ctx.local.keys()) await r.zadd('online', now, userId);
      const count = await onlineCount();
      for (const conns of ctx.local.values()) for (const c of conns) ctx.sendConn(c, msg('lobby:stats', { onlineCount: count }));
      dirty = false;
      await sendTo(subscribers());
    },

    /** Every lobbyPushMs: push the list if something changed. */
    async pushIfDirty() {
      if (!dirty) return;
      dirty = false;
      await sendTo(subscribers());
    },
  };
}
