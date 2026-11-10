import type { Color } from '@shaxmat/chess-core';

import type { Challenges } from './challenges.ts';
import type { Ctx } from './context.ts';
import type { Games } from './games.ts';

/**
 * All deadlines live in one Redis sorted set "timers" (member -> due time), so
 * any instance can fire them. Members:
 *   <gameId>:flag | <gameId>:abort | <gameId>:grace:<color> | <challengeId>:challenge
 */
export function createTimers(ctx: Ctx, games: Games, challenges: Challenges) {
  const { r, log } = ctx;

  return async function tick() {
    const due = await r.zrangebyscore('timers', 0, Date.now());
    for (const member of due) {
      if ((await r.zrem('timers', member)) !== 1) continue; // another instance took it
      const [id, kind, color] = member.split(':') as [string, string, Color | undefined];
      try {
        if (kind === 'challenge') await challenges.onExpire(id);
        else await games.onTimer(id, kind, color, member);
      } catch (e) {
        log(`timer ${member} failed: ${e}`);
      }
    }
  };
}
