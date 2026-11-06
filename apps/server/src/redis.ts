import { Redis } from 'ioredis';
import RedisMock from 'ioredis-mock';

export type RedisClient = Redis;

export interface RedisPair {
  /** Commands and publishing. */
  cmd: RedisClient;
  /** Subscriber connection (a subscribed connection can't run other commands). */
  sub: RedisClient;
}

/**
 * Real Redis when a URL is given. Without one, ioredis-mock: data and pub/sub
 * are shared by every mock created with the same `mockKey` in this process,
 * which is enough for local dev and for tests with several server instances.
 */
export function connectRedis(url: string | undefined, mockKey: string, log: (m: string) => void): RedisPair {
  if (url) {
    return { cmd: new Redis(url), sub: new Redis(url) };
  }
  log('REDIS_URL not set: using in-memory ioredis-mock (dev/tests only, state is lost on restart)');
  const Mock = RedisMock as unknown as new (o: { host: string }) => Redis;
  return { cmd: new Mock({ host: mockKey }), sub: new Mock({ host: mockKey }) };
}
