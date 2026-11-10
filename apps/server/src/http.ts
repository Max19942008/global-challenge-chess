import { createServer, type IncomingMessage, type ServerResponse } from 'node:http';

import { PROTOCOL_VERSION } from '@shaxmat/chess-core';

import type { Users } from './users.ts';

const AVATAR = /^\/avatar\/([0-9a-f-]{36})(?:\?.*)?$/;

/** Plain HTTP next to the WebSocket: health check and profile photos. */
export function createHttp(users: Users, log: (m: string) => void) {
  return createServer((req, res) => {
    route(req, res).catch((e) => {
      log(`http ${req.url} failed: ${e}`);
      if (!res.headersSent) res.writeHead(500);
      res.end();
    });
  });

  async function route(req: IncomingMessage, res: ServerResponse) {
    const url = req.url ?? '';
    if (url === '/health') {
      res.writeHead(200, { 'content-type': 'application/json' });
      res.end(JSON.stringify({ ok: true, protocol: PROTOCOL_VERSION }));
      return;
    }
    const avatar = AVATAR.exec(url);
    if (avatar && req.method === 'GET') {
      const img = await users.avatarBytes(avatar[1]!);
      if (!img) {
        res.writeHead(404).end();
        return;
      }
      res.writeHead(200, {
        'content-type': img.type,
        'content-length': img.bytes.length,
        // The URL carries ?v=<version>, so a new photo is a new URL.
        'cache-control': 'public, max-age=31536000, immutable',
        'access-control-allow-origin': '*',
      });
      res.end(img.bytes);
      return;
    }
    res.writeHead(404).end();
  }
}
