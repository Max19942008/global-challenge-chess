# WebSocket protocol v1

Source of truth for types: `packages/chess-core/src/events.ts`. Executable version:
`apps/server/test/protocol.test.ts` (fake clients play full games). Keep all three in sync.

- One WebSocket, JSON text frames. Every message: `{ "v": 1, "type": "...", ...payload }`.
- A message with another `v` gets `error unsupported_version`. Old clients keep working as long as `v` stays 1;
  breaking changes get `v: 2` and the server answers both for a while.
- **The server is the only source of truth.** Clients send intents; anything the client shows (board,
  clocks, result) is corrected by the next server message.

## Client → server

| type | payload | notes |
| --- | --- | --- |
| `auth:guest` | `{ name? }` | First launch: creates a guest user. Reply `auth:ok`. Store the token. |
| `auth` | `{ token }` | Every later connection. Reply `auth:ok`, or `error invalid_token` (then clear it and send `auth:guest`). |
| `ping` | `{ t }` | `t` = client `Date.now()`. Reply `pong`. Allowed before auth. |
| `queue:join` | `{ timeControl, rated }` | `"3+0"`, `"5+0"`, `"10+0"`. Joining again replaces the old entry. |
| `queue:leave` | — | Reply `queue:left`. |
| `queue:botAccept` | — | Leaves the queue (reply `queue:left`); the client then plays the bot locally. |
| `queue:botDecline` | — | Stay in the queue; no more bot offers in this queue session. |
| `game:move` | `{ gameId, uci, ply }` | `uci` standard (castling `e1g1`/`e1c1`/`e8g8`/`e8c8`, promotion `e7e8q`). `ply` = half-moves played **before** this move (White's first move: 0). |
| `game:resign` | `{ gameId }` | |
| `game:drawOffer` | `{ gameId }` | If the opponent already offered, this accepts. Any move cancels an open offer. |
| `game:drawRespond` | `{ gameId, accept }` | Only when the opponent's offer is open, else `error no_draw_offer`. |
| `game:sync` | `{ gameId }` | Reply `game:state`. Use after a reconnect or whenever the board looks wrong. |
| `game:claimVictory` | `{ gameId }` | Only after `opponent:abandoned`, else `error cannot_claim`. |

Anything except `auth`, `auth:guest`, `ping` before authentication → `error unauthenticated`.

## Server → client

| type | payload | when |
| --- | --- | --- |
| `auth:ok` | `{ token, user: { id, name, ratings } }` | After `auth` / `auth:guest`. `ratings` always has `bullet`, `blitz`, `rapid`: `{ rating, provisional }` (1500 / provisional for new players). |
| `pong` | `{ t, serverTime }` | Offset ≈ `serverTime − (sent + received) / 2`; take the sample with the smallest round trip out of ~5. |
| `lobby:stats` | `{ onlineCount }` | Right after `auth:ok`, then every ~5 s. |
| `queue:waiting` | `{ elapsedMs, onlineCount }` | Right after `queue:join`, then every ~2 s while queued. |
| `queue:botOffer` | `{ suggestedElo }` | After 15 s alone in the queue. The player **stays queued**: a `game:start` may still arrive and should close the offer. |
| `queue:left` | — | After `queue:leave` / `queue:botAccept`. |
| `game:start` | `{ gameId, color, opponent, timeControl, rated, fen, clocks, serverTime }` | Paired. `opponent = { id, name, rating, provisional }`. |
| `game:move` | `{ gameId, uci, fen, ply, clocks, serverTime }` | To **both** players, including the mover (this is the confirmation). `ply` = half-moves played **after** this move. |
| `game:state` | `{ gameId, fen, ply, moves, turn, clocks, serverTime, color, white, black, timeControl, rated }` | Reply to `game:sync`; after a rejected move; **unasked right after `auth:ok`** if the user has a game in progress. Redraw everything from it. |
| `game:drawOffer` | `{ gameId, from }` | Opponent offers a draw. |
| `game:drawDeclined` | `{ gameId }` | Your offer was declined. |
| `game:end` | `{ gameId, result, reason, ratingChange? }` | `result` `1-0`/`0-1`/`1/2-1/2`. `reason`: `checkmate`, `stalemate`, `threefold`, `fifty-move`, `insufficient`, `resign`, `timeout`, `abandon`, `draw-agreed`, `aborted`. `ratingChange = { before, after }` for the receiving player, only for rated games. For `aborted` ignore `result` (sent as `1/2-1/2`). |
| `opponent:disconnected` | `{ gameId, graceMs }` | Opponent's last connection closed. Their clock keeps running. |
| `opponent:reconnected` | `{ gameId }` | They're back. |
| `opponent:abandoned` | `{ gameId }` | Grace ran out. Show "Claim victory" (sends `game:claimVictory`); the player may also keep waiting. |
| `error` | `{ code, message }` | See below. |

### Clocks

`clocks = { white, black }` in ms, **as of `serverTime`**. The side to move's clock is running iff the
game is active and `ply ≥ 2`. Client display: `remaining = clocks[turn] − (serverNow − serverTime)` with
`serverNow = Date.now() + offset`. Time is deducted only when a move reaches the server; the increment is
added after the move. Each side's first move is free but must come within 30 s of the game start (White)
or of White's first move (Black), otherwise the game ends `aborted` (unrated). When the side to move runs
out → `game:end timeout`; it's a draw if the winner has only a king or king + one minor piece.

### Move rules

- `ply == server ply` and legal and your turn → applied, `game:move` to both.
- `ply < server ply` → stale (resent after reconnect). Ignored; if it doesn't match the move actually
  played at that ply, you also get `game:state`. Never an error.
- `ply > server ply` → `error bad_ply` + `game:state`.
- Not your turn → `error not_your_turn` + `game:state`. Illegal → `error illegal_move` + `game:state`.
- Optimistic UI: show your move at once, keep the last server-confirmed position, and on any error /
  `game:state` replace your board with the server's FEN.

### Error codes

| code | meaning |
| --- | --- |
| `unsupported_version` | `v` is not 1 |
| `bad_message` | not JSON, missing/unknown `type`, missing fields |
| `unauthenticated` | send `auth` / `auth:guest` first |
| `invalid_token` | token forged, from another server secret, or user gone → do `auth:guest` |
| `unknown_time_control` | not one of the allowed controls |
| `already_in_game` | can't queue while a game is in progress (sync it instead) |
| `no_game` | game doesn't exist or you're not in it |
| `game_over` | action on a finished game (you also get `game:state`) |
| `not_your_turn`, `illegal_move`, `bad_ply` | move refused (you also get `game:state`) |
| `no_draw_offer` | nothing to respond to |
| `cannot_claim` | opponent hasn't abandoned |
| `internal` | server bug; resync |

## Sequences

**First launch → game → end**

```
C: auth:guest {name?}            S: auth:ok {token, user}   (store token)
                                  S: lobby:stats {onlineCount}
C: queue:join {"5+0", rated}     S: queue:waiting {0, n} … every 2 s
                                  S: game:start {gameId, color, opponent, clocks, serverTime}
C(white): game:move {e2e4, ply 0}
                                  S→both: game:move {e2e4, fen, ply 1, clocks, serverTime}
C(black): game:move {e7e5, ply 1}
                                  S→both: game:move {…, ply 2}     (White's clock now runs)
…                                 S→each: game:end {result, reason, ratingChange}
```

**Nobody to play → bot**

```
C: queue:join                    S: queue:waiting …
                                  S: queue:botOffer {suggestedElo}   (after 15 s, still queued)
C: queue:botAccept               S: queue:left        → client starts a local bot game
   or queue:botDecline           (stays queued, no more offers; game:start may still come)
```

**Reconnect**

```
(socket drops)                    S→opponent: opponent:disconnected {graceMs}
C: auth {token}                   S: auth:ok, lobby:stats, game:state {full}  (unasked)
                                  S→opponent: opponent:reconnected
```

**Abandon**

```
(socket drops, no return)         S→opponent: opponent:disconnected {graceMs: 20000 (≤5 min) | 40000}
(grace over)                      S→opponent: opponent:abandoned
C(opponent): game:claimVictory    S→both: game:end {reason: abandon}
```
