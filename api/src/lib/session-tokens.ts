import {
  createPrivateKey,
  createPublicKey,
  generateKeyPairSync,
  randomUUID,
  sign,
  verify,
  type KeyObject,
} from 'node:crypto';
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
  const [header, body, signature] = token.split('.');
  if (!header || !body || !signature) throw unauthorized('Invalid access token');
  const parsedHeader = decodeJson<{ alg: string; typ: string; kid: string }>(header);
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
  const payload = decodeJson<AccessTokenPayload>(body);
  const now = Math.floor(Date.now() / 1000);
  if (payload.iss !== tokenIssuer() || payload.aud !== tokenAudience()) {
    throw unauthorized('Invalid access token');
  }
  if (payload.exp < now) throw unauthorized('Access token expired');
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

function decodeJson<T>(value: string): T {
  try {
    return JSON.parse(Buffer.from(value, 'base64url').toString()) as T;
  } catch {
    throw unauthorized('Invalid access token');
  }
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
  const privateKeyPem = process.env.ACCESS_TOKEN_PRIVATE_KEY_PEM;
  if (process.env.NODE_ENV === 'production' && !privateKeyPem) {
    throw new Error('ACCESS_TOKEN_PRIVATE_KEY_PEM is required in production');
  }
  return privateKeyPem ? createPrivateKey(privateKeyPem) : developmentKeyPair.privateKey;
}

function publicKey(): KeyObject {
  const publicKeyPem = process.env.ACCESS_TOKEN_PUBLIC_KEY_PEM;
  if (publicKeyPem) return createPublicKey(publicKeyPem);
  if (process.env.NODE_ENV === 'production') {
    throw new Error('ACCESS_TOKEN_PUBLIC_KEY_PEM is required in production');
  }
  return developmentKeyPair.publicKey;
}

function tokenKeyId() {
  return process.env.ACCESS_TOKEN_KID ?? 'local-development-key';
}

function tokenIssuer() {
  return process.env.ACCESS_TOKEN_ISSUER ?? 'cashflow-manager-api';
}

function tokenAudience() {
  return process.env.ACCESS_TOKEN_AUDIENCE ?? 'cashflow-manager-mobile';
}
