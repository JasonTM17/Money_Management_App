import { describe, expect, it } from 'vitest';
import {
  hashPassword,
  verifyPassword,
} from './passwords-and-tokens.js';
import { createAccessToken, getPublicJwks, verifyAccessToken } from './session-tokens.js';

function snapshotEnv(keys: string[]) {
  const snapshot = new Map(keys.map((key) => [key, process.env[key]]));
  return () => {
    for (const key of keys) {
      const value = snapshot.get(key);
      if (value === undefined) delete process.env[key];
      else process.env[key] = value;
    }
  };
}

describe('password hashing', () => {
  it('verifies matching passwords and rejects non-matching passwords', async () => {
    const hash = await hashPassword('correct-password');

    await expect(verifyPassword('correct-password', hash)).resolves.toBe(true);
    await expect(verifyPassword('wrong-password', hash)).resolves.toBe(false);
  });
});

describe('access tokens', () => {
  it('creates and verifies JWT bearer tokens', () => {
    const token = createAccessToken({
      sub: '59c80c94-4baf-42ab-a047-8d809f2dac32',
      email: 'demo@cashflow.local',
    });

    expect(token.split('.')).toHaveLength(3);
    expect(verifyAccessToken(token)).toMatchObject({
      sub: '59c80c94-4baf-42ab-a047-8d809f2dac32',
      email: 'demo@cashflow.local',
      aud: 'cashflow-manager-mobile',
      iss: 'cashflow-manager-api',
    });
    expect(getPublicJwks().keys[0]).toMatchObject({
      alg: 'EdDSA',
      kid: 'local-development-key',
      kty: 'OKP',
      use: 'sig',
    });
  });

  it('rejects tampered access tokens', () => {
    const token = createAccessToken({
      sub: '59c80c94-4baf-42ab-a047-8d809f2dac32',
      email: 'demo@cashflow.local',
    });
    const [header, body] = token.split('.');

    expect(() => verifyAccessToken(`${header}.${body}.tampered`)).toThrow(
      'Invalid access token',
    );
  });

  it('rejects tokens minted for a different audience', () => {
    const restoreEnv = snapshotEnv(['ACCESS_TOKEN_AUDIENCE']);
    process.env.ACCESS_TOKEN_AUDIENCE = 'cashflow-manager-mobile';
    const token = createAccessToken({
      sub: '59c80c94-4baf-42ab-a047-8d809f2dac32',
      email: 'demo@cashflow.local',
    });
    process.env.ACCESS_TOKEN_AUDIENCE = 'cashflow-manager-admin';

    try {
      expect(() => verifyAccessToken(token)).toThrow('Invalid access token');
    } finally {
      restoreEnv();
    }
  });

  it('rejects malformed token payload shape', () => {
    const token = createAccessToken({
      sub: '59c80c94-4baf-42ab-a047-8d809f2dac32',
      email: 'demo@cashflow.local',
    });
    const [header, _body, signature] = token.split('.');
    const malformedBody = Buffer.from(JSON.stringify({ exp: 'soon' })).toString('base64url');

    expect(() => verifyAccessToken(`${header}.${malformedBody}.${signature}`)).toThrow(
      'Invalid access token',
    );
  });
});
