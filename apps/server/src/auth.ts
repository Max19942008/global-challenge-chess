import { createHmac, timingSafeEqual } from 'node:crypto';

/** Token = base64url(userId) + "." + base64url(HMAC-SHA256(secret, userId)). No expiry yet (guests). */
export function signToken(secret: string, userId: string): string {
  const mac = createHmac('sha256', secret).update(userId).digest('base64url');
  return `${Buffer.from(userId).toString('base64url')}.${mac}`;
}

export function verifyToken(secret: string, token: unknown): string | null {
  if (typeof token !== 'string') return null;
  const [idPart, macPart] = token.split('.');
  if (!idPart || !macPart) return null;
  const userId = Buffer.from(idPart, 'base64url').toString();
  const expected = Buffer.from(createHmac('sha256', secret).update(userId).digest('base64url'));
  const given = Buffer.from(macPart);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) return null;
  return userId;
}
