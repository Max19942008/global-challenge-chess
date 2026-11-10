import { randomUUID } from 'node:crypto';

import type { AvatarPath, RatingCategory, UserInfo } from '@shaxmat/chess-core';

import { categories, categoryOf } from './config.ts';
import { errorMsg, msg, type Ctx, type Out } from './context.ts';
import type { Queryable } from './db.ts';
import type { Seat } from './games.ts';
import { DEFAULT_RATING, isProvisional, type Rating } from './rating.ts';

/** Largest accepted photo, decoded. Clients resize to ~256 px before sending. */
export const MAX_AVATAR_BYTES = 150 * 1024;
export const MAX_NAME = 24;

export function imageType(b: Buffer): string | null {
  if (b.length > 3 && b[0] === 0xff && b[1] === 0xd8 && b[2] === 0xff) return 'image/jpeg';
  if (b.length > 8 && b.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))) return 'image/png';
  if (b.length > 12 && b.toString('ascii', 0, 4) === 'RIFF' && b.toString('ascii', 8, 12) === 'WEBP') return 'image/webp';
  return null;
}

/** Versioned, so clients and proxies may cache it forever. */
export const avatarPath = (userId: string, ver: number, has: boolean): AvatarPath =>
  has ? `/avatar/${userId}?v=${ver}` : null;

interface UserRow {
  id: string;
  name: string;
  has_avatar: boolean;
  avatar_ver: number;
  wins: number;
  losses: number;
  draws: number;
}
const USER_COLS = 'id, name, avatar IS NOT NULL AS has_avatar, avatar_ver, wins, losses, draws';

export async function ratingOf(q: Queryable, userId: string, cat: RatingCategory): Promise<Rating> {
  const rows = await q.query<{ rating: number; rd: number; volatility: number }>(
    'SELECT rating, rd, volatility FROM ratings WHERE user_id = $1 AND category = $2',
    [userId, cat],
  );
  const row = rows[0];
  return row ? { rating: row.rating, rd: row.rd, vol: row.volatility } : { ...DEFAULT_RATING };
}

export type Users = ReturnType<typeof createUsers>;

export function createUsers(ctx: Ctx) {
  const { db } = ctx;

  /** Users with all three ratings, in two queries however many ids. */
  async function infoMany(ids: string[]): Promise<Map<string, UserInfo>> {
    const out = new Map<string, UserInfo>();
    if (ids.length === 0) return out;
    const users = await db.query<UserRow>(`SELECT ${USER_COLS} FROM users WHERE id = ANY($1)`, [ids]);
    const rows = await db.query<{ user_id: string; category: RatingCategory; rating: number; rd: number; volatility: number }>(
      'SELECT user_id, category, rating, rd, volatility FROM ratings WHERE user_id = ANY($1)',
      [ids],
    );
    for (const u of users) {
      const ratings = {} as UserInfo['ratings'];
      for (const cat of categories) {
        const row = rows.find((x) => x.user_id === u.id && x.category === cat);
        const rt = row ? { rating: row.rating, rd: row.rd, vol: row.volatility } : { ...DEFAULT_RATING };
        ratings[cat] = { rating: Math.round(rt.rating), provisional: isProvisional(rt) };
      }
      out.set(u.id, {
        id: u.id,
        name: u.name,
        avatar: avatarPath(u.id, u.avatar_ver, u.has_avatar),
        ratings,
        stats: { wins: u.wins, losses: u.losses, draws: u.draws },
      });
    }
    return out;
  }

  const info = async (userId: string) => (await infoMany([userId])).get(userId) ?? null;

  async function createGuest(name: unknown): Promise<string> {
    const userId = randomUUID();
    const clean = typeof name === 'string' && name.trim() ? name.trim().slice(0, MAX_NAME) : null;
    await db.query('INSERT INTO users (id, name) VALUES ($1, $2)', [
      userId,
      clean ?? `Guest-${1000 + Math.floor(Math.random() * 9000)}`,
    ]);
    return userId;
  }

  const exists = async (userId: string) => (await db.query('SELECT 1 FROM users WHERE id = $1', [userId])).length > 0;

  /** profile:update. Returns the reply (profile:ok or an error). */
  async function updateProfile(userId: string, name: unknown, avatar: unknown): Promise<Out> {
    if (name !== undefined) {
      if (typeof name !== 'string') return errorMsg('bad_name', 'name must be a string');
      const clean = name.trim().replace(/\s+/g, ' ');
      if (clean.length < 2 || clean.length > MAX_NAME) return errorMsg('bad_name', `Name must be 2–${MAX_NAME} characters`);
      await db.query('UPDATE users SET name = $2 WHERE id = $1', [userId, clean]);
    }
    if (avatar === null) {
      await db.query('UPDATE users SET avatar = NULL, avatar_type = NULL, avatar_ver = avatar_ver + 1 WHERE id = $1', [userId]);
    } else if (avatar !== undefined) {
      if (typeof avatar !== 'string') return errorMsg('bad_avatar', 'avatar must be base64 or null');
      const bytes = Buffer.from(avatar, 'base64');
      const type = imageType(bytes);
      if (!type) return errorMsg('bad_avatar', 'Only JPEG, PNG or WebP');
      if (bytes.length > MAX_AVATAR_BYTES) return errorMsg('bad_avatar', `At most ${MAX_AVATAR_BYTES / 1024} KB`);
      await db.query('UPDATE users SET avatar = $2, avatar_type = $3, avatar_ver = avatar_ver + 1 WHERE id = $1', [
        userId,
        bytes,
        type,
      ]);
    }
    return msg('profile:ok', { user: (await info(userId))! });
  }

  async function avatarBytes(userId: string): Promise<{ bytes: Buffer; type: string } | null> {
    const rows = await db.query<{ avatar: Uint8Array | null; avatar_type: string | null }>(
      'SELECT avatar, avatar_type FROM users WHERE id = $1',
      [userId],
    );
    const row = rows[0];
    if (!row?.avatar || !row.avatar_type) return null;
    return { bytes: Buffer.from(row.avatar), type: row.avatar_type };
  }

  /** What a new game needs to know about this player, for the queue or a challenge. */
  async function seat(userId: string, tc: string, rated: boolean): Promise<Seat | null> {
    const u = await info(userId);
    if (!u) return null;
    const rt = await ratingOf(db, userId, categoryOf(tc));
    return { userId, name: u.name, tc, rated, rating: rt.rating, provisional: isProvisional(rt), avatar: u.avatar };
  }

  return {
    info,
    infoMany,
    seat,
    rating: (userId: string, cat: RatingCategory) => ratingOf(db, userId, cat),
    createGuest,
    exists,
    updateProfile,
    avatarBytes,
  };
}
