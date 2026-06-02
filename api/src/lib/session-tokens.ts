import {
  createPrivateKey,
  createPublicKey,
  generateKeyPairSync,
  randomUUID,
  sign,
  verify,
  type KeyObject,
} from 'node:crypto';
import { env } from './env.js';
import { unauthorized } from './api-error.js';

const accessTokenTtlSeconds = 900;
const tokenAlgorithm = 'EdDSA';
const tokenType = 'JWT';

const developmentKeyPair = generateKeyPairSync('ed25519');

type AccessTokenPayload = {
  iss: string;
  aud: string;
  sub: string;
  email: string;
  iat: number;
  exp: number;
  jti: string;
};

type AccessTokenHeader = {
  alg: string;
  typ: string;
  kid: string;
};

export function createAccessToken(payload: Pick<AccessTokenPayload, 'sub' | 'email'>) {
  const now = Math.floor(Date.now() / 1000);
  const header = encodeJson({
    alg: tokenAlgorithm,
    typ: tokenType,
    kid: tokenKeyId(),
  });
  const body = encodeJson({
    iss: tokenIssuer(),
    aud: tokenAudience(),
    sub: payload.sub,
    email: payload.email,
    iat: now,
    exp: now + accessTokenTtlSeconds,
    jti: randomUUID(),
  } satisfies AccessTokenPayload);
  return `${header}.${body}.${signToken(`${header}.${body}`)}`;
}

export function verifyAccessToken(token: string): AccessTokenPayload {
  const [header, body, signature, extra] = token.split('.');
  if (!header || !body || !signature || extra) throw unauthorized('Invalid access token');
  const parsedHeader = accessTokenHeader(decodeJson(header));
  if (
    parsedHeader.alg !== tokenAlgorithm ||
    parsedHeader.typ !== tokenType ||
    parsedHeader.kid !== tokenKeyId()
  ) {
    throw unauthorized('Invalid access token');
  }
  if (!verifyToken(`${header}.${body}`, signature)) {
    throw unauthorized('Invalid access token');
  }
  const payload = accessTokenPayload(decodeJson(body));
  const now = Math.floor(Date.now() / 1000);
  if (payload.iss !== tokenIssuer() || payload.aud !== tokenAudience()) {
    throw unauthorized('Invalid access token');
  }
  if (payload.iat > now + 60 || payload.exp <= now) throw unauthorized('Access token expired');
  return payload;
}

export function getPublicJwks() {
  const jwk = publicKey().export({ format: 'jwk' });
  return {
    keys: [
      {
        ...jwk,
        alg: tokenAlgorithm,
        kid: tokenKeyId(),
        use: 'sig',
      },
    ],
  };
}

export function accessTokenExpiresIn() {
  return accessTokenTtlSeconds;
}

export function createRefreshTokenExpiry() {
  return new Date(Date.now() + 1000 * 60 * 60 * 24 * 30);
}

function encodeJson(value: unknown) {
  return Buffer.from(JSON.stringify(value)).toString('base64url');
}

function decodeJson(value: string): unknown {
  try {
    return JSON.parse(Buffer.from(value, 'base64url').toString()) as unknown;
  } catch {
    throw unauthorized('Invalid access token');
  }
}

function accessTokenHeader(value: unknown): AccessTokenHeader {
  if (!isRecord(value)) throw unauthorized('Invalid access token');
  const { alg, typ, kid } = value;
  if (typeof alg !== 'string' || typeof typ !== 'string' || typeof kid !== 'string') {
    throw unauthorized('Invalid access token');
  }
  return { alg, typ, kid };
}

function accessTokenPayload(value: unknown): AccessTokenPayload {
  if (!isRecord(value)) throw unauthorized('Invalid access token');
  const { iss, aud, sub, email, iat, exp, jti } = value;
  if (
    typeof iss !== 'string' ||
    typeof aud !== 'string' ||
    typeof sub !== 'string' ||
    typeof email !== 'string' ||
    typeof jti !== 'string' ||
    typeof iat !== 'number' ||
    typeof exp !== 'number' ||
    !Number.isInteger(iat) ||
    !Number.isInteger(exp) ||
    exp <= iat
  ) {
    throw unauthorized('Invalid access token');
  }
  return { iss, aud, sub, email, iat, exp, jti };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function signToken(value: string) {
  return sign(null, Buffer.from(value), privateKey()).toString('base64url');
}

function verifyToken(value: string, signature: string) {
  try {
    return verify(
      null,
      Buffer.from(value),
      publicKey(),
      Buffer.from(signature, 'base64url'),
    );
  } catch {
    return false;
  }
}

function privateKey(): KeyObject {
  const privateKeyPem = env.jwtPrivateKey;
  if (env.NODE_ENV === 'production' && !privateKeyPem) {
    throw new Error('jwtPrivateKey is required in production');
  }
  return privateKeyPem ? createPrivateKey(privateKeyPem) : developmentKeyPair.privateKey;
}

function publicKey(): KeyObject {
  const publicKeyPem = env.jwtPublicKey;
  if (publicKeyPem) return createPublicKey(publicKeyPem);
  if (env.NODE_ENV === 'production') {
    throw new Error('jwtPublicKey is required in production');
  }
  return developmentKeyPair.publicKey;
}

function tokenKeyId() {
  return env.ACCESS_TOKEN_KID;
}

function tokenIssuer() {
  return env.ACCESS_TOKEN_ISSUER;
}

function tokenAudience() {
  return env.ACCESS_TOKEN_AUDIENCE;
}
