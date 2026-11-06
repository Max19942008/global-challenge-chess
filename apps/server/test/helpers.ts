import { randomUUID } from 'node:crypto';

import type { ClientMessage, ServerMessage } from '@shaxmat/chess-core';
import WebSocket from 'ws';

import { startServer, type RunningServer, type ServerOptions } from '../src/server.ts';

export const TEST_TC = '0.02+0'; // 1.2 s per side, for timeout tests

/** Fast delays so the whole suite runs in seconds. */
export async function testServer(extra: ServerOptions = {}): Promise<RunningServer> {
  return startServer({
    port: 0,
    mockRedisKey: `test-${randomUUID()}`,
    tokenSecret: 'test-secret',
    timeControls: ['3+0', '5+0', '10+0', TEST_TC],
    log: () => {},
    ...extra,
    delays: {
      botOfferMs: 300,
      abortMs: 600,
      graceShortMs: 300,
      graceLongMs: 300,
      matchTickMs: 40,
      timerTickMs: 20,
      waitingEveryMs: 100,
      statsEveryMs: 200,
      windowAfterMs: [100, 200, 300],
      windowRange: [100, 200, 400],
      ...extra.delays,
    },
  });
}

type Out = ServerMessage;
type In = ClientMessage;
type Payload<T extends In['type']> = Omit<Extract<In, { type: T }>, 'v' | 'type'>;

/** A scripted protocol client: records everything, lets tests await specific messages. */
export class Client {
  readonly ws: WebSocket;
  readonly all: Out[] = [];
  private unread: Out[] = [];
  private waiters: { match: (m: Out) => boolean; resolve: (m: Out) => void }[] = [];
  userId = '';
  token = '';

  private constructor(ws: WebSocket) {
    this.ws = ws;
    ws.on('message', (data) => {
      const m = JSON.parse(data.toString()) as Out;
      this.all.push(m);
      const i = this.waiters.findIndex((w) => w.match(m));
      if (i >= 0) this.waiters.splice(i, 1)[0]!.resolve(m);
      else this.unread.push(m);
    });
  }

  static async connect(url: string): Promise<Client> {
    const ws = new WebSocket(url);
    await new Promise<void>((res, rej) => {
      ws.once('open', () => res());
      ws.once('error', rej);
    });
    return new Client(ws);
  }

  /** Connects and signs in as a new guest (or with a token). */
  static async guest(url: string, name?: string): Promise<Client> {
    const c = await Client.connect(url);
    c.send('auth:guest', name ? { name } : {});
    const ok = await c.next('auth:ok');
    c.userId = ok.user.id;
    c.token = ok.token;
    return c;
  }

  static async withToken(url: string, token: string): Promise<Client> {
    const c = await Client.connect(url);
    c.send('auth', { token });
    const ok = await c.next('auth:ok');
    c.userId = ok.user.id;
    c.token = ok.token;
    return c;
  }

  send<T extends In['type']>(type: T, payload: Payload<T>) {
    this.ws.send(JSON.stringify({ v: 1, type, ...payload }));
  }

  sendRaw(obj: unknown) {
    this.ws.send(JSON.stringify(obj));
  }

  /** Next message of this type (already received ones first). */
  next<T extends Out['type']>(type: T, ms = 3000, where: (m: Extract<Out, { type: T }>) => boolean = () => true) {
    const match = (m: Out) => m.type === type && where(m as Extract<Out, { type: T }>);
    const i = this.unread.findIndex(match);
    if (i >= 0) return Promise.resolve(this.unread.splice(i, 1)[0] as Extract<Out, { type: T }>);
    return new Promise<Extract<Out, { type: T }>>((resolve, reject) => {
      const timer = setTimeout(() => {
        this.waiters = this.waiters.filter((w) => w.resolve !== done);
        reject(new Error(`timeout waiting for ${type}; got: ${this.all.map((m) => m.type).join(', ')}`));
      }, ms);
      const done = (m: Out) => {
        clearTimeout(timer);
        resolve(m as Extract<Out, { type: T }>);
      };
      this.waiters.push({ match, resolve: done });
    });
  }

  /** Asserts no message of this type arrives within ms. */
  async none(type: Out['type'], ms = 250) {
    try {
      const m = await this.next(type, ms);
      throw new Error(`unexpected ${type}: ${JSON.stringify(m)}`);
    } catch (e) {
      if (String(e).includes('unexpected')) throw e;
    }
  }

  close() {
    this.ws.close();
  }
}

/** Two guests queue for the same control and get paired; returns them as white/black. */
export async function pairUp(url: string, tc = '5+0', rated = true, url2 = url) {
  const a = await Client.guest(url, 'Alice');
  const b = await Client.guest(url2, 'Bob');
  a.send('queue:join', { timeControl: tc, rated });
  b.send('queue:join', { timeControl: tc, rated });
  const sa = await a.next('game:start');
  const sb = await b.next('game:start');
  const white = sa.color === 'white' ? a : b;
  const black = sa.color === 'white' ? b : a;
  return { white, black, start: sa, startB: sb, gameId: sa.gameId };
}

/** Plays alternating moves (ply counted from 0) and waits until both sides saw each one. */
export async function play(white: Client, black: Client, gameId: string, moves: string[]) {
  for (let i = 0; i < moves.length; i++) {
    const mover = i % 2 === 0 ? white : black;
    mover.send('game:move', { gameId, uci: moves[i]!, ply: i });
    await white.next('game:move', 3000, (m) => m.ply === i + 1);
    await black.next('game:move', 3000, (m) => m.ply === i + 1);
  }
}
