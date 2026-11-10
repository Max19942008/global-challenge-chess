import { randomBytes } from 'node:crypto';

import type { ChallengeClosedReason, PlayerInfo } from '@shaxmat/chess-core';

import { errorMsg, msg, type Ctx, type Out } from './context.ts';
import type { Games, Seat } from './games.ts';
import type { Lobby } from './lobby.ts';
import type { Queue } from './queue.ts';
import type { Users } from './users.ts';

/** Redis hash challenge:{id}; user:{id}:challenge points at the sender's open one. */
interface ChallengeRec {
  id: string;
  from: string;
  to: string;
  tc: string;
  rated: boolean;
}

const asPlayer = (s: Seat): PlayerInfo => ({
  id: s.userId,
  name: s.name,
  rating: Math.round(s.rating),
  provisional: s.provisional,
  avatar: s.avatar,
});

export type Challenges = ReturnType<typeof createChallenges>;

/** Direct games: challenge a "ready" player from the lobby; they accept or decline. */
export function createChallenges(ctx: Ctx, users: Users, games: Games, lobby: Lobby, queue: Queue) {
  const { r, d, timeControls, toUser } = ctx;
  const outgoingKey = (userId: string) => `user:${userId}:challenge`;

  async function load(id: string): Promise<ChallengeRec | null> {
    const h = await r.hgetall(`challenge:${id}`);
    if (!h?.id) return null;
    return { id: h.id, from: h.from!, to: h.to!, tc: h.tc!, rated: h.rated === '1' };
  }

  /**
   * Removes the challenge. Whoever deletes the hash owns it, so concurrent
   * accept/cancel/expiry can't both act. Returns false if it was already gone.
   */
  async function take(c: ChallengeRec): Promise<boolean> {
    if ((await r.del(`challenge:${c.id}`)) !== 1) return false;
    if ((await r.get(outgoingKey(c.from))) === c.id) await r.del(outgoingKey(c.from));
    await r.zrem('timers', `${c.id}:challenge`);
    return true;
  }

  async function close(c: ChallengeRec, reason: ChallengeClosedReason) {
    if (!(await take(c))) return;
    await notifyClosed(c, reason);
  }

  async function notifyClosed(c: ChallengeRec, reason: ChallengeClosedReason) {
    const m = msg('challenge:closed', { challengeId: c.id, reason });
    await toUser(c.from, m);
    await toUser(c.to, m);
  }

  async function cancelOutgoing(userId: string) {
    const id = await r.get(outgoingKey(userId));
    const c = id ? await load(id) : null;
    if (c) await close(c, 'cancelled');
  }

  async function send(userId: string, to: unknown, tc: unknown, rated: boolean): Promise<Out | null> {
    if (typeof to !== 'string' || typeof tc !== 'string') return errorMsg('bad_message', 'to and timeControl required');
    if (!timeControls.includes(tc)) return errorMsg('unknown_time_control', `Allowed: ${timeControls.join(', ')}`);
    if (to === userId) return errorMsg('player_unavailable', 'You cannot challenge yourself');
    if (await games.inGame(userId)) return errorMsg('already_in_game', 'Finish your current game first');
    if (!(await ctx.isConnected(to)) || (await lobby.status(to)) !== 'ready') {
      return errorMsg('player_unavailable', 'That player is not taking challenges right now');
    }
    const [me, them] = await Promise.all([users.seat(userId, tc, rated), users.seat(to, tc, rated)]);
    if (!me || !them) return errorMsg('player_unavailable', 'Unknown player');

    await cancelOutgoing(userId);
    const c: ChallengeRec = { id: randomBytes(6).toString('base64url'), from: userId, to, tc, rated };
    const tx = r.multi();
    tx.hset(`challenge:${c.id}`, { id: c.id, from: c.from, to: c.to, tc: c.tc, rated: rated ? '1' : '0' });
    tx.pexpire(`challenge:${c.id}`, d.challengeMs + 60_000); // the timer closes it; this is only cleanup
    tx.set(outgoingKey(userId), c.id);
    tx.zadd('timers', Date.now() + d.challengeMs, `${c.id}:challenge`);
    await tx.exec();

    const common = { challengeId: c.id, timeControl: tc, rated, expiresInMs: d.challengeMs };
    await toUser(to, msg('challenge:incoming', { ...common, from: asPlayer(me) }));
    return msg('challenge:sent', { ...common, to: asPlayer(them) });
  }

  async function respond(userId: string, id: unknown, accept: boolean): Promise<Out | null> {
    const c = typeof id === 'string' ? await load(id) : null;
    if (!c || c.to !== userId) return errorMsg('no_challenge', 'No such challenge for you');
    if (!accept) {
      await close(c, 'declined');
      return null;
    }
    const available =
      (await ctx.isConnected(c.from)) && !(await games.inGame(c.from)) && !(await games.inGame(c.to));
    if (!available) {
      await close(c, 'unavailable');
      return null;
    }
    if (!(await take(c))) return errorMsg('no_challenge', 'The challenge is no longer open');
    const [a, b] = await Promise.all([users.seat(c.from, c.tc, c.rated), users.seat(c.to, c.tc, c.rated)]);
    if (!a || !b) {
      await notifyClosed(c, 'unavailable');
      return null;
    }
    await queue.leave(c.from);
    await queue.leave(c.to);
    await notifyClosed(c, 'accepted');
    await games.create(a, b);
    return null;
  }

  async function cancel(userId: string, id: unknown): Promise<Out | null> {
    const c = typeof id === 'string' ? await load(id) : null;
    if (!c || c.from !== userId) return errorMsg('no_challenge', 'No such challenge of yours');
    await close(c, 'cancelled');
    return null;
  }

  /** Timer "<id>:challenge" came due. */
  async function onExpire(id: string) {
    const c = await load(id);
    if (c) await close(c, 'expired');
  }

  return { send, respond, cancel, onExpire, onDisconnect: cancelOutgoing };
}
