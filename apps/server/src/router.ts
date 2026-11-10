import { PROTOCOL_VERSION, type ClientMessage } from '@shaxmat/chess-core';

import { signToken, verifyToken } from './auth.ts';
import type { Challenges } from './challenges.ts';
import { errorMsg, msg, type Conn, type Ctx, type Out } from './context.ts';
import type { Games } from './games.ts';
import { leaderboard } from './leaderboard.ts';
import type { Lobby } from './lobby.ts';
import type { Queue } from './queue.ts';
import type { Users } from './users.ts';

interface Modules {
  users: Users;
  lobby: Lobby;
  games: Games;
  queue: Queue;
  challenges: Challenges;
}

/** Sign-in, sign-out and the message switch: every client message lands here first. */
export function createRouter(ctx: Ctx, secret: string, { users, lobby, games, queue, challenges }: Modules) {
  const { r, local } = ctx;

  async function onAuthed(conn: Conn, userId: string, token: string) {
    conn.userId = userId;
    let set = local.get(userId);
    if (!set) local.set(userId, (set = new Set()));
    set.add(conn);
    await r.hincrby('conns', userId, 1);
    await lobby.onConnect(userId);

    ctx.sendConn(conn, msg('auth:ok', { token, user: (await users.info(userId))! }));
    ctx.sendConn(conn, msg('lobby:stats', { onlineCount: await lobby.onlineCount() }));
    await games.onConnect(conn, userId);
  }

  async function onClose(conn: Conn) {
    const userId = conn.userId;
    if (!userId) return;
    local.get(userId)?.delete(conn);
    if (local.get(userId)?.size === 0) local.delete(userId);
    if ((await r.hincrby('conns', userId, -1)) > 0) return;
    await r.hdel('conns', userId);
    await queue.leave(userId);
    await challenges.onDisconnect(userId);
    await lobby.onDisconnect(userId);
    await games.onDisconnect(userId);
  }

  async function onMessage(conn: Conn, raw: string): Promise<Out | null> {
    let m: ClientMessage;
    try {
      m = JSON.parse(raw);
    } catch {
      return errorMsg('bad_message', 'Not JSON');
    }
    if (!m || typeof m !== 'object' || typeof m.type !== 'string') return errorMsg('bad_message', 'Missing type');
    if (m.v !== PROTOCOL_VERSION) return errorMsg('unsupported_version', `Server speaks v${PROTOCOL_VERSION}`);

    if (m.type === 'ping') return msg('pong', { t: m.t, serverTime: Date.now() });
    if (m.type === 'auth:guest') {
      if (conn.userId) return errorMsg('bad_message', 'Already authenticated');
      const userId = await users.createGuest(m.name);
      await onAuthed(conn, userId, signToken(secret, userId));
      return null;
    }
    if (m.type === 'auth') {
      const userId = verifyToken(secret, m.token);
      if (!userId || !(await users.exists(userId))) return errorMsg('invalid_token', 'Unknown or invalid token');
      if (conn.userId && conn.userId !== userId) return errorMsg('bad_message', 'Already authenticated');
      if (!conn.userId) await onAuthed(conn, userId, m.token);
      return null;
    }

    const userId = conn.userId;
    if (!userId) return errorMsg('unauthenticated', 'Send auth or auth:guest first');

    switch (m.type) {
      case 'queue:join':
        return queue.join(userId, m.timeControl, m.rated !== false);
      case 'queue:leave':
      case 'queue:botAccept':
        await queue.leave(userId);
        return msg('queue:left', {});
      case 'queue:botDecline':
        await queue.botDecline(userId);
        return null;

      case 'game:move':
      case 'game:resign':
      case 'game:drawOffer':
      case 'game:drawRespond':
      case 'game:sync':
      case 'game:claimVictory':
        if (typeof m.gameId !== 'string') return errorMsg('bad_message', 'gameId required');
        return games.onAction(userId, m);

      case 'profile:update': {
        const reply = await users.updateProfile(userId, m.name, m.avatar);
        if (reply.type === 'profile:ok') lobby.changed();
        return reply;
      }

      case 'lobby:subscribe':
        await lobby.subscribe(conn);
        return null;
      case 'lobby:unsubscribe':
        lobby.unsubscribe(conn);
        return null;
      case 'lobby:status':
        if (m.status !== 'watching' && m.status !== 'ready') return errorMsg('bad_message', 'status: watching | ready');
        await lobby.setStatus(userId, m.status);
        return null;

      case 'challenge:send':
        return challenges.send(userId, m.to, m.timeControl, m.rated !== false);
      case 'challenge:respond':
        return challenges.respond(userId, m.challengeId, m.accept === true);
      case 'challenge:cancel':
        return challenges.cancel(userId, m.challengeId);

      case 'leaderboard:get':
        return leaderboard(ctx, userId, m.category, m.sort);

      default:
        return errorMsg('bad_message', `Unknown type ${(m as { type: string }).type}`);
    }
  }

  return { onMessage, onClose };
}
