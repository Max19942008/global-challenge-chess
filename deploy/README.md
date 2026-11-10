# VPS deploy

(`apps/server/deploy.sh` is the other route: a dedicated VPS where the game server
runs its own Caddy on 80/443. Use this folder when sharing the MotoHub VPS.)

Runs on the same VPS as MotoHub (`ubuntu@43.202.41.127`, folder `~/apps/chess`).
MotoHub's Caddy holds ports 80/443 and gets HTTPS certificates; this project adds
one site file to it.

| Address | Goes to |
| --- | --- |
| `https://$CHESS_DOMAIN` | `chess-web`: Flutter web build (static) |
| `wss://$CHESS_DOMAIN/ws` | `chess-server`: online games |
| `https://$CHESS_DOMAIN/health` | server health check |
| `https://$CHESS_DOMAIN/avatar/<id>` | profile photos (served by the game server) |

Redis and Postgres are only on the project's internal network.

## First time

1. DNS: an `A` record for the domain (and `www` if wanted) pointing to `43.202.41.127`.
2. On the server, `~/apps/chess/deploy/.env`:

   ```
   TOKEN_SECRET=<openssl rand -hex 32>
   POSTGRES_PASSWORD=<openssl rand -hex 16>
   ```

   Changing `TOKEN_SECRET` later logs every guest out.
3. `~/apps/motohub/.env`: `CHESS_DOMAIN=<domain>`, and copy `deploy/chess.caddy` to
   `~/apps/motohub/caddy-sites/`. Then recreate Caddy:
   `cd ~/apps/motohub && docker compose -f docker-compose.prod.yml up -d caddy`.

## Each release

Build the web app on a PC. `flutter build web --wasm` also compiles a JavaScript
fallback, and dartchess cannot compile to JavaScript (64-bit integer literals),
so build through `flutter run`, which makes the WASM version only:

```bash
cd apps/mobile
flutter run -d web-server --release --wasm --web-port 8099 --dart-define=SERVER_URL=wss://<domain>/ws
# wait for "is being served", press q; the files are in build/web
```

Browsers without WebAssembly GC (old Safari) cannot open the web version.

Copy the repository (without `node_modules`) and `apps/mobile/build/web` to
`~/apps/chess` / `~/apps/chess/deploy/web`, then:

```bash
cd ~/apps/chess/deploy && docker compose -f docker-compose.vps.yml up -d --build
```

The Android build must use the same address:
`flutter build appbundle --release --dart-define=SERVER_URL=wss://<domain>/ws`.
