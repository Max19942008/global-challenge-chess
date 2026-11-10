/**
 * Lobby, profiles, challenges and the leaderboard: the social side of online play.
 */
import assert from 'node:assert/strict';
import { after, before, describe, test } from 'node:test';

import type { RunningServer } from '../src/server.ts';
import { Client, play, testServer } from './helpers.ts';

const FOOLS_MATE = ['f2f3', 'e7e5', 'g2g4', 'd8h4'];
/** Smallest valid PNG (1×1). */
const PNG_1PX =
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

const httpUrl = (s: RunningServer, path: string) => `http://localhost:${s.port}${path}`;

/** Challenges `b` (who must be ready) and returns both sides' views once b accepts. */
async function challengeAndAccept(a: Client, b: Client, tc = '5+0') {
  a.send('challenge:send', { to: b.userId, timeControl: tc, rated: true });
  const sent = await a.next('challenge:sent');
  const incoming = await b.next('challenge:incoming');
  assert.equal(incoming.challengeId, sent.challengeId);
  b.send('challenge:respond', { challengeId: sent.challengeId, accept: true });
  const startA = await a.next('game:start');
  const startB = await b.next('game:start');
  const white = startA.color === 'white' ? a : b;
  const black = startA.color === 'white' ? b : a;
  return { sent, incoming, startA, startB, white, black, gameId: startA.gameId };
}

async function ready(...cs: Client[]) {
  for (const c of cs) c.send('lobby:status', { status: 'ready' });
  // Let the status land before anyone challenges.
  await new Promise((r) => setTimeout(r, 50));
}

describe('profile', () => {
  let s: RunningServer;
  before(async () => (s = await testServer()));
  after(async () => s.close());

  test('auth:ok carries avatar and win/loss/draw counters', async () => {
    const c = await Client.guest(s.url);
    const ok = c.all.find((m) => m.type === 'auth:ok');
    assert.ok(ok && ok.type === 'auth:ok');
    assert.equal(ok.user.avatar, null);
    assert.deepEqual(ok.user.stats, { wins: 0, losses: 0, draws: 0 });
    c.close();
  });

  test('rename, upload a photo, fetch it over HTTP, remove it', async () => {
    const c = await Client.guest(s.url);
    c.send('profile:update', { name: '  Bobur   R ' });
    assert.equal((await c.next('profile:ok')).user.name, 'Bobur R');

    c.send('profile:update', { avatar: PNG_1PX });
    const withPhoto = (await c.next('profile:ok')).user;
    assert.match(withPhoto.avatar!, new RegExp(`^/avatar/${withPhoto.id}\\?v=\\d+$`));
    const res = await fetch(httpUrl(s, withPhoto.avatar!));
    assert.equal(res.status, 200);
    assert.equal(res.headers.get('content-type'), 'image/png');
    assert.deepEqual(Buffer.from(await res.arrayBuffer()), Buffer.from(PNG_1PX, 'base64'));

    c.send('profile:update', { avatar: null });
    assert.equal((await c.next('profile:ok')).user.avatar, null);
    assert.equal((await fetch(httpUrl(s, withPhoto.avatar!))).status, 404);
    c.close();
  });

  test('bad names and bad images are refused', async () => {
    const c = await Client.guest(s.url);
    c.send('profile:update', { name: 'x' });
    assert.equal((await c.next('error')).code, 'bad_name');
    c.send('profile:update', { avatar: Buffer.from('not an image').toString('base64') });
    assert.equal((await c.next('error')).code, 'bad_avatar');
    const huge = Buffer.concat([Buffer.from([0xff, 0xd8, 0xff]), Buffer.alloc(200 * 1024)]);
    c.send('profile:update', { avatar: huge.toString('base64') });
    assert.equal((await c.next('error')).code, 'bad_avatar');
    c.close();
  });
});

describe('lobby', () => {
  let s: RunningServer;
  before(async () => (s = await testServer()));
  after(async () => s.close());

  test('subscribers see everyone with status, and changes arrive without polling', async () => {
    const a = await Client.guest(s.url, 'Ann');
    const b = await Client.guest(s.url, 'Ben');
    a.send('lobby:subscribe', {});
    const first = await a.next('lobby:players');
    const ben = first.players.find((p) => p.id === b.userId);
    assert.equal(ben?.status, 'watching');
    assert.equal(ben?.name, 'Ben');
    assert.ok(first.onlineCount >= 2);

    b.send('lobby:status', { status: 'ready' });
    await a.next('lobby:players', 3000, (m) => m.players.some((p) => p.id === b.userId && p.status === 'ready'));

    b.close();
    await a.next('lobby:players', 3000, (m) => !m.players.some((p) => p.id === b.userId));
    a.close();
  });

  test('ready players come first; players in a game show as playing', async () => {
    const a = await Client.guest(s.url, 'Ali');
    const b = await Client.guest(s.url, 'Bek');
    const watcher = await Client.guest(s.url, 'Watcher');
    await ready(a, b);
    watcher.send('lobby:subscribe', {});
    const list = (await watcher.next('lobby:players')).players;
    const ids = list.map((p) => p.id);
    assert.ok(ids.indexOf(a.userId) < ids.indexOf(watcher.userId), 'ready before watching');

    await challengeAndAccept(a, b);
    await watcher.next('lobby:players', 3000, (m) =>
      [a.userId, b.userId].every((id) => m.players.find((p) => p.id === id)?.status === 'playing'),
    );
    for (const c of [a, b, watcher]) c.close();
  });

  test('unsubscribe stops the list', async () => {
    const a = await Client.guest(s.url);
    a.send('lobby:subscribe', {});
    await a.next('lobby:players');
    a.send('lobby:unsubscribe', {});
    await new Promise((r) => setTimeout(r, 50));
    await a.none('lobby:players', 450);
    a.close();
  });
});

describe('challenges', () => {
  let s: RunningServer;
  before(async () => (s = await testServer()));
  after(async () => s.close());

  test('accept starts a game between the two, with avatars on both sides', async () => {
    const a = await Client.guest(s.url, 'Asal');
    const b = await Client.guest(s.url, 'Bobur');
    a.send('profile:update', { avatar: PNG_1PX });
    const aAvatar = (await a.next('profile:ok')).user.avatar;
    await ready(b);

    const { sent, incoming, startA, startB, white, black, gameId } = await challengeAndAccept(a, b, '3+0');
    assert.equal(sent.to.name, 'Bobur');
    assert.equal(incoming.from.name, 'Asal');
    assert.equal(incoming.from.avatar, aAvatar);
    assert.equal(incoming.timeControl, '3+0');
    assert.equal(startA.gameId, startB.gameId);
    assert.equal(startB.opponent.avatar, aAvatar);
    assert.equal((await a.next('challenge:closed')).reason, 'accepted');

    await play(white, black, gameId, FOOLS_MATE);
    assert.equal((await white.next('game:end')).result, '0-1');
    a.close();
    b.close();
  });

  test('decline, cancel and expiry close it for both sides', async () => {
    const a = await Client.guest(s.url);
    const b = await Client.guest(s.url);
    await ready(b);

    a.send('challenge:send', { to: b.userId, timeControl: '5+0', rated: true });
    let id = (await a.next('challenge:sent')).challengeId;
    await b.next('challenge:incoming');
    b.send('challenge:respond', { challengeId: id, accept: false });
    assert.equal((await a.next('challenge:closed', 3000, (m) => m.challengeId === id)).reason, 'declined');
    assert.equal((await b.next('challenge:closed', 3000, (m) => m.challengeId === id)).reason, 'declined');

    a.send('challenge:send', { to: b.userId, timeControl: '5+0', rated: true });
    id = (await a.next('challenge:sent')).challengeId;
    a.send('challenge:cancel', { challengeId: id });
    assert.equal((await b.next('challenge:closed', 3000, (m) => m.challengeId === id)).reason, 'cancelled');

    a.send('challenge:send', { to: b.userId, timeControl: '5+0', rated: true });
    id = (await a.next('challenge:sent')).challengeId;
    assert.equal((await a.next('challenge:closed', 3000, (m) => m.challengeId === id)).reason, 'expired');
    b.send('challenge:respond', { challengeId: id, accept: true });
    assert.equal((await b.next('error')).code, 'no_challenge');
    a.close();
    b.close();
  });

  test('only ready, online players can be challenged; never yourself', async () => {
    const a = await Client.guest(s.url);
    const b = await Client.guest(s.url);
    a.send('challenge:send', { to: b.userId, timeControl: '5+0', rated: true });
    assert.equal((await a.next('error')).code, 'player_unavailable'); // b is watching
    a.send('challenge:send', { to: a.userId, timeControl: '5+0', rated: true });
    assert.equal((await a.next('error')).code, 'player_unavailable');
    a.send('challenge:send', { to: b.userId, timeControl: '7+0', rated: true });
    assert.equal((await a.next('error')).code, 'unknown_time_control');
    a.close();
    b.close();
  });

  test('a challenger who disconnects withdraws the challenge', async () => {
    const a = await Client.guest(s.url);
    const b = await Client.guest(s.url);
    await ready(b);
    a.send('challenge:send', { to: b.userId, timeControl: '5+0', rated: true });
    const id = (await a.next('challenge:sent')).challengeId;
    await b.next('challenge:incoming');
    a.close();
    assert.equal((await b.next('challenge:closed', 3000, (m) => m.challengeId === id)).reason, 'cancelled');
    b.close();
  });
});

describe('leaderboard', () => {
  let s: RunningServer;
  before(async () => (s = await testServer()));
  after(async () => s.close());

  test('wins/losses are counted; winners rank higher by rating and by wins', async () => {
    const a = await Client.guest(s.url, 'Winner');
    const b = await Client.guest(s.url, 'Loser');
    await ready(a, b);
    for (let i = 0; i < 2; i++) {
      const { white, black, gameId } = await challengeAndAccept(i === 0 ? a : b, i === 0 ? b : a);
      // The loser resigns, whoever has which colour.
      (white === b ? white : black).send('game:resign', { gameId });
      await white.next('game:end');
      await black.next('game:end');
    }

    a.send('leaderboard:get', { category: 'blitz', sort: 'rating' });
    const byRating = await a.next('leaderboard');
    assert.equal(byRating.category, 'blitz');
    assert.deepEqual(
      byRating.players.map((p) => [p.rank, p.name, p.wins, p.losses]),
      [
        [1, 'Winner', 2, 0],
        [2, 'Loser', 0, 2],
      ],
    );
    assert.ok(byRating.players[0]!.rating > byRating.players[1]!.rating);
    assert.equal(byRating.players[0]!.games, 2);
    assert.equal(byRating.me?.rank, 1);

    b.send('leaderboard:get', { sort: 'wins' });
    const byWins = await b.next('leaderboard');
    assert.equal(byWins.sort, 'wins');
    assert.equal(byWins.players[0]!.name, 'Winner');
    assert.equal(byWins.me?.name, 'Loser');
    assert.equal(byWins.me?.rank, 2);

    a.send('leaderboard:get', { category: 'rapid' });
    const rapid = await a.next('leaderboard');
    assert.deepEqual(rapid.players, []);
    assert.equal(rapid.me, null);

    // A fresh login sees the counters.
    const again = await Client.withToken(s.url, a.token);
    const ok = again.all.find((m) => m.type === 'auth:ok');
    assert.ok(ok && ok.type === 'auth:ok');
    assert.deepEqual(ok.user.stats, { wins: 2, losses: 0, draws: 0 });
    for (const c of [a, b, again]) c.close();
  });
});
