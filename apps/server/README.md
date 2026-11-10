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

Any Linux VPS (AWS EC2/Lightsail, Hetzner…) with ports 22, 80 and 443 open. From the repo root:

```bash
apps/server/deploy.sh ubuntu@<server IP>                    # no domain yet: wss://<IP>.sslip.io
apps/server/deploy.sh ubuntu@<server IP> chess.example.uz   # with a domain (A record -> server IP)
SSH_KEY=path/to/key.pem apps/server/deploy.sh ubuntu@<IP>   # with an AWS .pem key
```

It installs Docker, clones/updates the repo in `/opt/global-challenge-chess`, creates
`apps/server/.env` with `TOKEN_SECRET` and `POSTGRES_PASSWORD` once (kept on later runs), and starts
server + Redis + Postgres + Caddy (`docker-compose.yml`). Caddy gets the HTTPS certificate itself.
Run it again after every push to update. The server port 8080 is bound to localhost only.

## Source layout (`src/`)

| File | What's in it |
| --- | --- |
| `index.ts` | Reads env vars, starts the server |
| `server.ts` | Wires the modules, HTTP + WebSocket, the loops |
| `router.ts` | Sign-in/sign-out and the message switch |
| `context.ts` | Shared plumbing: Redis, DB, delivery to users/games, locks |
| `users.ts` | Users, ratings, profile (name + photo) |
| `lobby.ts` | Who's online and their status (watching / ready / playing) |
| `queue.ts` | Random matchmaking by rating, bot offer |
| `challenges.ts` | Direct challenges between lobby players |
| `games.ts` | Live games: moves, clocks, draw/resign, end of game, saving |
| `timers.ts` | Flag / abort / grace / challenge-expiry deadlines |
| `leaderboard.ts` | Top players by rating or wins |
| `http.ts` | `/health`, `/avatar/:id` |
| `db.ts`, `redis.ts`, `auth.ts`, `rating.ts`, `config.ts` | Storage, tokens, Glicko-2, timings |

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
