import type { LeaderboardEntry, LeaderboardSort, RatingCategory } from '@shaxmat/chess-core';

import { categories } from './config.ts';
import { msg, type Ctx, type Out } from './context.ts';
import { DEFAULT_RATING, isProvisional } from './rating.ts';
import { avatarPath } from './users.ts';

const TOP = 50;

interface Row {
  id: string;
  name: string;
  has_avatar: boolean;
  avatar_ver: number;
  wins: number;
  losses: number;
  draws: number;
  rating: number | null;
  rd: number | null;
  volatility: number | null;
  games: number | null;
}

const SELECT = `
  SELECT u.id, u.name, u.avatar IS NOT NULL AS has_avatar, u.avatar_ver, u.wins, u.losses, u.draws,
         r.rating, r.rd, r.volatility, r.games
  FROM users u LEFT JOIN ratings r ON r.user_id = u.id AND r.category = $1`;

/**
 * Rated games in the category, strongest first; or any finished game, most wins first.
 * `better` counts players ranked above a value ($2); every query takes the category as $1.
 */
const QUERIES: Record<LeaderboardSort, { where: string; order: string; better: string }> = {
  rating: {
    where: 'r.games > 0',
    order: 'r.rating DESC, u.wins DESC',
    better: 'SELECT count(*)::int AS n FROM ratings WHERE category = $1 AND games > 0 AND rating > $2',
  },
  wins: {
    where: 'u.wins + u.losses + u.draws > 0',
    order: 'u.wins DESC, u.losses ASC, r.rating DESC NULLS LAST',
    better: 'SELECT count(*)::int AS n FROM users WHERE $1::text IS NOT NULL AND wins + losses + draws > 0 AND wins > $2',
  },
};

function toEntry(row: Row, rank: number): LeaderboardEntry {
  const rt = row.rating === null ? DEFAULT_RATING : { rating: row.rating, rd: row.rd!, vol: row.volatility! };
  return {
    rank,
    id: row.id,
    name: row.name,
    avatar: avatarPath(row.id, row.avatar_ver, row.has_avatar),
    rating: Math.round(rt.rating),
    provisional: isProvisional(rt),
    games: row.games ?? 0,
    wins: row.wins,
    losses: row.losses,
    draws: row.draws,
  };
}

/** leaderboard:get — top players by rating or by wins, plus the asker's own rank. */
export async function leaderboard(ctx: Ctx, userId: string, category: unknown, sort: unknown): Promise<Out> {
  const cat: RatingCategory = categories.includes(category as RatingCategory) ? (category as RatingCategory) : 'blitz';
  const by: LeaderboardSort = sort === 'wins' ? 'wins' : 'rating';
  const q = QUERIES[by];

  const rows = await ctx.db.query<Row>(`${SELECT} WHERE ${q.where} ORDER BY ${q.order} LIMIT ${TOP}`, [cat]);
  const players = rows.map((row, i) => toEntry(row, i + 1));

  let me = players.find((p) => p.id === userId) ?? null;
  if (!me) {
    const mine = (await ctx.db.query<Row>(`${SELECT} WHERE u.id = $2 AND ${q.where}`, [cat, userId]))[0];
    if (mine) {
      const key = by === 'rating' ? mine.rating : mine.wins;
      const better = (await ctx.db.query<{ n: number }>(q.better, [cat, key]))[0]?.n ?? 0;
      me = toEntry(mine, better + 1);
    }
  }
  return msg('leaderboard', { category: cat, sort: by, players, me });
}
