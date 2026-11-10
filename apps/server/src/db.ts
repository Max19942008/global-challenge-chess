import { PGlite } from '@electric-sql/pglite';
import pg from 'pg';

export interface Queryable {
  query<T = Record<string, unknown>>(sql: string, params?: unknown[]): Promise<T[]>;
}

/** Finished games, users and ratings. Nothing is written here while a game is running. */
export interface Db extends Queryable {
  tx<T>(fn: (q: Queryable) => Promise<T>): Promise<T>;
  close(): Promise<void>;
}

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  abandons INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS ratings (
  user_id TEXT NOT NULL REFERENCES users(id),
  category TEXT NOT NULL,
  rating DOUBLE PRECISION NOT NULL,
  rd DOUBLE PRECISION NOT NULL,
  volatility DOUBLE PRECISION NOT NULL,
  games INTEGER NOT NULL DEFAULT 0,
  PRIMARY KEY (user_id, category)
);
CREATE TABLE IF NOT EXISTS games (
  id TEXT PRIMARY KEY,
  white TEXT NOT NULL REFERENCES users(id),
  black TEXT NOT NULL REFERENCES users(id),
  time_control TEXT NOT NULL,
  rated BOOLEAN NOT NULL,
  vs_bot BOOLEAN NOT NULL DEFAULT false,
  result TEXT NOT NULL,
  reason TEXT NOT NULL,
  moves TEXT NOT NULL,
  pgn TEXT,
  started_at TIMESTAMPTZ NOT NULL,
  ended_at TIMESTAMPTZ NOT NULL
);
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar BYTEA;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_type TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS avatar_ver INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS wins INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS losses INTEGER NOT NULL DEFAULT 0;
ALTER TABLE users ADD COLUMN IF NOT EXISTS draws INTEGER NOT NULL DEFAULT 0;
CREATE INDEX IF NOT EXISTS ratings_board ON ratings (category, rating DESC);
`;

/** Postgres when DATABASE_URL is set; otherwise PGlite (Postgres in-process, in memory). */
export async function openDb(url: string | undefined, log: (m: string) => void): Promise<Db> {
  const db = url ? pgDb(url) : await pgliteDb(log);
  for (const stmt of SCHEMA.split(';').map((s) => s.trim()).filter(Boolean)) {
    await db.query(stmt);
  }
  return db;
}

function pgDb(url: string): Db {
  const pool = new pg.Pool({ connectionString: url });
  const run = async <T>(c: pg.Pool | pg.PoolClient, sql: string, params?: unknown[]) =>
    (await c.query(sql, params as unknown[])).rows as T[];
  return {
    query: (sql, params) => run(pool, sql, params),
    async tx(fn) {
      const client = await pool.connect();
      try {
        await client.query('BEGIN');
        const out = await fn({ query: (sql, params) => run(client, sql, params) });
        await client.query('COMMIT');
        return out;
      } catch (e) {
        await client.query('ROLLBACK');
        throw e;
      } finally {
        client.release();
      }
    },
    close: () => pool.end(),
  };
}

async function pgliteDb(log: (m: string) => void): Promise<Db> {
  log('DATABASE_URL not set: using in-memory PGlite (dev/tests only, data is lost on restart)');
  const lite = new PGlite();
  await lite.waitReady;
  return {
    query: async (sql, params) => (await lite.query(sql, params)).rows as never,
    tx: (fn) =>
      lite.transaction((t) => fn({ query: async (sql, params) => (await t.query(sql, params)).rows as never })),
    close: () => lite.close(),
  };
}
