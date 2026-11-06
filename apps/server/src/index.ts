import { startServer } from './server.ts';

const server = await startServer({
  port: Number(process.env.PORT ?? 8080),
  redisUrl: process.env.REDIS_URL || undefined,
  databaseUrl: process.env.DATABASE_URL || undefined,
  tokenSecret: process.env.TOKEN_SECRET || undefined,
});

for (const sig of ['SIGINT', 'SIGTERM'] as const) {
  process.on(sig, () => {
    server.close().finally(() => process.exit(0));
  });
}
