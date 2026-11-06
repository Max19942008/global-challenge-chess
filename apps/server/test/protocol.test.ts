/**
 * The executable protocol document: fake clients play complete games against
 * a real server (in-memory Redis + PGlite). Flutter must follow the same sequences.
 */
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import { randomUUID } from 'node:crypto';
import { glickoForTest, rateGame } from '../src/rating.ts';
import type { RunningServer } from '../src/server.ts';
import { Client, TEST_TC, pairUp, play, testServer } from './helpers.ts';

const FOOLS_MATE = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];

describe('ratings', () => {
  test("Glicko-2 matches Glickman's worked example", () => {
    const g = glickoForTest();
    const p = g.makePlayer(1500, 200, 0.06);
    g.updateRatings([
      [p, g.makePlayer(1400, 30, 0.06), 1],
      [p, g.makePlayer(1550, 100, 0.06), 0],
      [p, g.makePlayer(1700, 300, 0.06), 0],
    ]);
    assert.ok(Math.abs(p.getRating() - 1464.06) < 0.05, `rating ${p.getRating()}`);
    assert.ok(Math.abs(p.getRd() - 151.52) < 0.05, `rd ${p.getRd()}`);
  });

  test('a win moves new players a lot (high RD)', () => {
    const r = rateGame({ rating: 1500, rd: 350, vol: 0.06 }, { rating: 1500, rd: 350, vol: 0.06 }, 1);
    assert.ok(r.white.rating > 1600 && r.black.rating < 1400);
  });
});

describe('protocol', () => {
  let s: RunningServer;
  before(async () => {
    s = await testServer();
  });
  after(async () => {
    await s.close();
  });

  test('version, auth required, guest auth, token reuse, forged token', async () => {
    const c = await Client.connect(s.url);
    c.sendRaw({ v: 2, type: 'ping', t: 1 });
    assert.equal((await c.next('error')).code, 'unsupported_version');
    c.send('queue:join', { timeControl: '5+0', rated: true });
    assert.equal((await c.next('error')).code, 'unauthenticated');
    c.send('ping', { t: 42 });
    const pong = await c.next('pong');
    assert.equal(pong.t, 42);
    assert.ok(Math.abs(pong.serverTime - Date.now()) < 1000);

    c.send('auth:guest', {});
    const ok = await c.next('auth:ok');
    assert.match(ok.user.name, /^Guest-\d{4}$/);
    assert.deepEqual(Object.keys(ok.user.ratings).sort(), ['blitz', 'bullet', 'rapid']);
    assert.deepEqual(ok.user.ratings.blitz, { rating: 1500, provisional: true });
    assert.ok((await c.next('lobby:stats')).onlineCount >= 1);
    c.close();

    const again = await Client.withToken(s.url, ok.token);
    assert.equal(again.userId, ok.user.id);
    again.close();

    const forged = await Client.connect(s.url);
    forged.send('auth', { token: ok.token.slice(0, -2) + 'xx' });
    assert.equal((await forged.next('error')).code, 'invalid_token');
    forged.send('auth', { token: Buffer.from(randomUUID()).toString('base64url') + '.abc' });
    assert.equal((await forged.next('error')).code, 'invalid_token');
    forged.close();
  });

  test('two guests are paired with opposite colours and full clocks', async () => {
    const { white, black, start, startB } = await pairUp(s.url, '5+0');
    assert.notEqual(start.color, startB.color);
    assert.equal(start.gameId, startB.gameId);
    assert.deepEqual(start.clocks, { white: 300_000, black: 300_000 });
    assert.equal(start.rated, true);
    assert.equal(start.fen, 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1');
    const names = [start.opponent.name, startB.opponent.name].sort();
    assert.deepEqual(names, ['Alice', 'Bob']);
    assert.equal(start.opponent.rating, 1500);
    white.close();
    black.close();
  });

  test('moves: broadcast, out of turn, illegal, bad ply, duplicate', async () => {
    const { white, black, gameId } = await pairUp(s.url);
    white.send('game:move', { gameId, uci: 'e2e4', ply: 0 });
    const mw = await white.next('game:move');
    const mb = await black.next('game:move');
    assert.equal(mw.ply, 1);
    assert.equal(mb.uci, 'e2e4');
    assert.equal(mb.fen, 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1');
    assert.ok(mb.serverTime > 0 && mb.clocks.white === 300_000);

    white.send('game:move', { gameId, uci: 'd2d4', ply: 1 });
    assert.equal((await white.next('error')).code, 'not_your_turn');
    assert.equal((await white.next('game:state')).ply, 1);

    black.send('game:move', { gameId, uci: 'e7e4', ply: 1 });
    assert.equal((await black.next('error')).code, 'illegal_move');
    assert.deepEqual((await black.next('game:state')).moves, ['e2e4']);

    black.send('game:move', { gameId, uci: 'e7e5', ply: 7 });
    assert.equal((await black.next('error')).code, 'bad_ply');
    await black.next('game:state');

    // Resent after a flaky connection: silently ignored, never applied twice.
    white.send('game:move', { gameId, uci: 'e2e4', ply: 0 });
    await white.none('error');
    await white.none('game:move');

    black.send('game:move', { gameId, uci: 'e7e5', ply: 1 });
    assert.equal((await white.next('game:move')).ply, 2);

    white.send('game:sync', { gameId });
    const st = await white.next('game:state');
    assert.deepEqual(st.moves, ['e2e4', 'e7e5']);
    assert.equal(st.turn, 'white');
    assert.equal(st.color, 'white');
    assert.equal(st.white.name === 'Alice' || st.white.name === 'Bob', true);

    const stranger = await Client.guest(s.url);
    stranger.send('game:move', { gameId, uci: 'g1f3', ply: 2 });
    assert.equal((await stranger.next('error')).code, 'no_game');
    stranger.close();
    white.close();
    black.close();
  });

  test("fool's mate ends the game, rates both and writes the database", async () => {
    const { white, black, gameId } = await pairUp(s.url);
    await play(white, black, gameId, FOOLS_MATE);
    const ew = await white.next('game:end');
    const eb = await black.next('game:end');
    assert.equal(ew.result, '0-1');
    assert.equal(ew.reason, 'checkmate');
    assert.ok(ew.ratingChange && ew.ratingChange.after < ew.ratingChange.before);
    assert.ok(eb.ratingChange && eb.ratingChange.after > eb.ratingChange.before);

    const rows = await s.db.query<{ result: string; reason: string; moves: string; rated: boolean }>(
      'SELECT result, reason, moves, rated FROM games WHERE id = $1',
      [gameId],
    );
    assert.deepEqual(rows[0], { result: '0-1', reason: 'checkmate', moves: FOOLS_MATE.join(' '), rated: true });
    const ratings = await s.db.query<{ user_id: string; games: number }>(
      'SELECT user_id, games FROM ratings WHERE user_id = ANY($1) AND category = $2',
      [[white.userId, black.userId], 'blitz'],
    );
    assert.equal(ratings.length, 2);
    assert.ok(ratings.every((r) => r.games === 1));

    // Moves after the end are refused.
    white.send('game:move', { gameId, uci: 'a2a3', ply: 4 });
    assert.equal((await white.next('error')).code, 'game_over');

    // The game is no longer "current": queueing again works.
    white.send('queue:join', { timeControl: '5+0', rated: true });
    await white.next('queue:waiting');
    white.send('queue:leave', {});
    await white.next('queue:left');
    white.close();
    black.close();
  });

  test('unrated game changes no rating', async () => {
    const { white, black, gameId, start } = await pairUp(s.url, '10+0', false);
    assert.equal(start.rated, false);
    await play(white, black, gameId, FOOLS_MATE);
    const e = await white.next('game:end');
    assert.equal(e.ratingChange, undefined);
    white.close();
    black.close();
  });

  test('resign', async () => {
    const { white, black, gameId } = await pairUp(s.url);
    await play(white, black, gameId, ['e2e4', 'e7e5']);
    black.send('game:resign', { gameId });
    const e = await white.next('game:end');
    assert.deepEqual([e.result, e.reason], ['1-0', 'resign']);
    white.close();
    black.close();
  });

  test('draw offer: declined, then accepted', async () => {
    const { white, black, gameId } = await pairUp(s.url);
    await play(white, black, gameId, ['e2e4', 'e7e5']);
    white.send('game:drawOffer', { gameId });
    assert.equal((await black.next('game:drawOffer')).from, 'white');
    black.send('game:drawRespond', { gameId, accept: false });
    await white.next('game:drawDeclined');

    black.send('game:drawRespond', { gameId, accept: true });
    assert.equal((await black.next('error')).code, 'no_draw_offer');

    black.send('game:drawOffer', { gameId });
    await white.next('game:drawOffer');
    white.send('game:drawRespond', { gameId, accept: true });
    const e = await black.next('game:end');
    assert.deepEqual([e.result, e.reason], ['1/2-1/2', 'draw-agreed']);
    white.close();
    black.close();
  });

  test('flag: the side to move runs out of time', async () => {
    const { white, black, gameId } = await pairUp(s.url, TEST_TC);
    await play(white, black, gameId, ['e2e4', 'e7e5']); // first moves are free; now white's clock runs
    const e = await black.next('game:end', 4000);
    assert.deepEqual([e.result, e.reason], ['0-1', 'timeout']);
    white.close();
    black.close();
  });

  test('a move that arrives after the flag loses on time', async () => {
    const { white, black, gameId } = await pairUp(s.url, TEST_TC, true);
    await play(white, black, gameId, ['e2e4', 'e7e5']);
    await new Promise((r) => setTimeout(r, 1300));
    white.send('game:move', { gameId, uci: 'g1f3', ply: 2 });
    const e = await white.next('game:end', 3000);
    assert.equal(e.reason, 'timeout');
    white.close();
    black.close();
  });

  test('nobody moves: the game is aborted, unrated', async () => {
    const { white, black } = await pairUp(s.url);
    const e = await white.next('game:end', 3000);
    assert.equal(e.reason, 'aborted');
    assert.equal(e.ratingChange, undefined);
    await black.next('game:end');
    white.close();
    black.close();
  });

  test('reconnect mid-game: full state unasked, opponent told', async () => {
    const { white, black, gameId } = await pairUp(s.url);
    await play(white, black, gameId, ['e2e4', 'e7e5']);
    white.close();
    const dis = await black.next('opponent:disconnected');
    assert.equal(dis.graceMs, 300);
    const back = await Client.withToken(s.url, white.token);
    const st = await back.next('game:state');
    assert.equal(st.gameId, gameId);
    assert.deepEqual(st.moves, ['e2e4', 'e7e5']);
    assert.equal(st.color, 'white');
    await black.next('opponent:reconnected');
    // and play continues
    back.send('game:move', { gameId, uci: 'g1f3', ply: 2 });
    assert.equal((await black.next('game:move')).uci, 'g1f3');
    back.close();
    black.close();
  });

  test('abandon: grace runs out, opponent claims the win', async () => {
    const { white, black, gameId } = await pairUp(s.url);
    await play(white, black, gameId, ['e2e4', 'e7e5']);
    black.send('game:claimVictory', { gameId });
    assert.equal((await black.next('error')).code, 'cannot_claim');
    white.close();
    await black.next('opponent:disconnected');
    await black.next('opponent:abandoned', 2000);
    black.send('game:claimVictory', { gameId });
    const e = await black.next('game:end');
    assert.deepEqual([e.result, e.reason], ['0-1', 'abandon']);
    assert.ok(e.ratingChange);
    const u = await s.db.query<{ abandons: number }>('SELECT abandons FROM users WHERE id = $1', [white.userId]);
    assert.equal(u[0]!.abandons, 1);
    black.close();
  });

  test('alone in the queue: bot offer, decline is final, then leave', async () => {
    const c = await Client.guest(s.url);
    c.send('queue:join', { timeControl: '3+0', rated: true });
    const w = await c.next('queue:waiting');
    assert.equal(w.elapsedMs, 0);
    const offer = await c.next('queue:botOffer', 2000);
    assert.equal(offer.suggestedElo, 1500);
    c.send('queue:botDecline', {});
    await c.next('queue:waiting', 1000, (m) => m.elapsedMs > 300); // still queued
    await c.none('queue:botOffer', 500);
    c.send('queue:leave', {});
    await c.next('queue:left');

    c.send('queue:join', { timeControl: '3+0', rated: true });
    await c.next('queue:botOffer', 2000); // a new queue session may offer again
    c.send('queue:botAccept', {});
    await c.next('queue:left');
    c.close();
  });

  test('a player still in the queue during the bot offer can be matched', async () => {
    const a = await Client.guest(s.url);
    a.send('queue:join', { timeControl: '10+0', rated: true });
    await a.next('queue:botOffer', 2000);
    const b = await Client.guest(s.url);
    b.send('queue:join', { timeControl: '10+0', rated: true });
    const st = await a.next('game:start');
    assert.equal((await b.next('game:start')).gameId, st.gameId);
    a.close();
    b.close();
  });

  test('unknown time control and joining while in a game are refused', async () => {
    const c = await Client.guest(s.url);
    c.send('queue:join', { timeControl: '7+7', rated: true });
    assert.equal((await c.next('error')).code, 'unknown_time_control');
    c.close();
    const { white, black } = await pairUp(s.url);
    white.send('queue:join', { timeControl: '5+0', rated: true });
    assert.equal((await white.next('error')).code, 'already_in_game');
    white.close();
    black.close();
  });
});

describe('two server instances on one Redis', () => {
  let s1: RunningServer;
  let s2: RunningServer;
  before(async () => {
    const key = `shared-${randomUUID()}`;
    s1 = await testServer({ mockRedisKey: key });
    s2 = await testServer({ mockRedisKey: key, db: s1.db });
  });
  after(async () => {
    await s2.close();
    await s1.close();
  });

  test('players on different instances find each other and see every move', async () => {
    const { white, black, gameId } = await pairUp(s1.url, '5+0', true, s2.url);
    await play(white, black, gameId, FOOLS_MATE);
    assert.equal((await white.next('game:end')).reason, 'checkmate');
    assert.equal((await black.next('game:end')).reason, 'checkmate');
    white.close();
    black.close();
  });
});
