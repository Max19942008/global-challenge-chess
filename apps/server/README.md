# apps/server

Online play: matchmaking, server-authoritative games with clocks, Glicko-2 ratings.
Protocol: [`docs/protocol.md`](../../docs/protocol.md) (types: `packages/chess-core/src/events.ts`).

## Run locally

```bash
npm install            # from the repo root
npm run server         # ws://localhost:8080, health: http://localhost:8080/health
npm test -w @shaxmat/server
```

Without `REDIS_URL` / `DATABASE_URL` the server uses **in-memory** ioredis-mock and PGlite
(Postgres compiled to WASM, in process). Good for development and tests; everything is lost on restart.

## Environment

| Variable | Default | Notes |
| --- | --- | --- |
| `PORT` | `8080` | HTTP + WebSocket on the same port |
| `REDIS_URL` | in-memory mock | e.g. `redis://localhost:6379`. Live games, queue, timers, pub/sub |
| `DATABASE_URL` | in-memory PGlite | e.g. `postgres://user:pass@host:5432/db`. Users, ratings, finished games |
| `TOKEN_SECRET` | dev secret (warns) | HMAC key for guest tokens. **Set a long random value in production**; changing it logs everyone out |

Tables are created on start (`CREATE TABLE IF NOT EXISTS`).

## Deploy (one VPS with Docker)

```bash
export TOKEN_SECRET=$(openssl rand -hex 32) POSTGRES_PASSWORD=$(openssl rand -hex 16)
docker compose -f apps/server/docker-compose.yml up -d --build
```

Put it behind HTTPS (Caddy / nginx / a cloud load balancer) so clients connect with `wss://`.
Several server containers can share one Redis: moves travel over Redis pub/sub (`game:{id}`, `user:{id}`),
matchmaking is guarded by a Redis lock, and timers live in a Redis sorted set.

## Design notes

- **Server is the only source of truth.** Clients send intents (`game:move` with `ply`), the server
  validates with `@shaxmat/chess-core` (the same code the web client uses) and broadcasts the result.
- **Live state in Redis, finished state in Postgres.** Nothing hits Postgres during a game; at the end
  the game row and both rating updates go in one transaction.
- **Clocks** are deducted only when a move arrives; a Redis timer per game fires the flag. Each side's
  first move is free, but must come within 30 s or the game is aborted (unrated).
- **Bot games never reach the server**: on `queue:botAccept` the server only drops the player from the queue.
- Deviation from the plan doc: plain [`ws`](https://github.com/websockets/ws) instead of NestJS — the
  server is one module with a small message switch, and the protocol is plain JSON so the Flutter client
  needs no Socket.IO.

## Not done yet

- Real accounts (email/password); guests only. A guest who loses the token (reinstall) gets a new user.
- Lag compensation (fine for 3+0 and longer; needed before bullet).
- Abandon penalties are counted (`users.abandons`) but not yet used for matchmaking.
- Rate limiting / abuse protection on the socket.
