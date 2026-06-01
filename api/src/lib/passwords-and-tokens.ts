import { pbkdf2 as pbkdf2Callback, randomBytes, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';

const pbkdf2 = promisify(pbkdf2Callback);
const passwordIterations = 210000;
const keyLength = 32;
const digest = 'sha256';

export async function hashPassword(password: string) {
  const salt = randomBytes(16).toString('base64url');
  const hash = await pbkdf2(password, salt, passwordIterations, keyLength, digest);
  return `pbkdf2-sha256$${passwordIterations}$${salt}$${hash.toString('base64url')}`;
}

export async function verifyPassword(password: string, storedHash: string) {
  const [algorithm, iterationsValue, salt, hashValue] = storedHash.split('$');
  if (algorithm !== 'pbkdf2-sha256' || !iterationsValue || !salt || !hashValue) {
    return false;
  }
  const iterations = Number.parseInt(iterationsValue, 10);
  if (!Number.isInteger(iterations) || iterations <= 0) return false;
  const expected = Buffer.from(hashValue, 'base64url');
  const actual = await pbkdf2(password, salt, iterations, expected.length, digest);
  return expected.length === actual.length && timingSafeEqual(expected, actual);
}

export function createOpaqueToken() {
  return randomBytes(32).toString('base64url');
}

export async function hashOpaqueToken(token: string) {
  const hash = await pbkdf2(token, 'refresh-token-v1', 120000, keyLength, digest);
  return hash.toString('base64url');
}
