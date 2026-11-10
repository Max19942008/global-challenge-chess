import { errorMsg, msg, type Ctx, type Out } from './context.ts';
import type { Games, Seat } from './games.ts';
import type { Lobby } from './lobby.ts';
import type { Users } from './users.ts';

/** A player waiting for a random opponent. Redis: zset queue:{tc}:{rated|casual} + hash queue:joined. */
interface QueueEntry extends Seat {
  at: number;
  key: string;
}

const queueKey = (tc: string, rated: boolean) => `queue:${tc}:${rated ? 'rated' : 'casual'}`;

export type Queue = ReturnType<typeof createQueue>;

/** Random pairing by rating, with a window that widens the longer someone waits, and a bot offer. */
export function createQueue(ctx: Ctx, users: Users, games: Games, lobby: Lobby) {
  const { r, d, timeControls, toUser } = ctx;
  const lastWaitingSent = new Map<string, number>();

  async function leave(userId: string): Promise<boolean> {
    const raw = await r.hget('queue:joined', userId);
    if (!raw) return false;
    const e = JSON.parse(raw) as QueueEntry;
    await r.zrem(e.key, userId);
    await r.hdel('queue:joined', userId);
    await r.hdel('queue:bot', userId);
    lastWaitingSent.delete(userId);
    return true;
  }

  async function join(userId: string, tc: string, rated: boolean): Promise<Out> {
    if (!timeControls.includes(tc)) return errorMsg('unknown_time_control', `Allowed: ${timeControls.join(', ')}`);
    if (await games.inGame(userId)) return errorMsg('already_in_game', 'Finish or sync your current game first');
    await leave(userId);
    const seat = await users.seat(userId, tc, rated);
    if (!seat) return errorMsg('unauthenticated', 'Unknown user');
    const entry: QueueEntry = { ...seat, at: Date.now(), key: queueKey(tc, rated) };
    await r.zadd(entry.key, entry.rating, userId);
    await r.hset('queue:joined', userId, JSON.stringify(entry));
    await r.hdel('queue:bot', userId);
    lastWaitingSent.set(userId, Date.now());
    return msg('queue:waiting', { elapsedMs: 0, onlineCount: await lobby.onlineCount() });
  }

  async function botDecline(userId: string) {
    if (await r.hget('queue:joined', userId)) await r.hset('queue:bot', userId, 'declined');
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

  /** Every matchTickMs, on one instance at a time. */
  async function tick() {
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
          await games.create(p, best);
        }
      }

      const count = all.length - used.size > 0 ? await lobby.onlineCount() : 0;
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

  return { join, leave, botDecline, tick };
}
