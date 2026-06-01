import { describe, expect, it } from 'vitest';
import { buildApp } from '../../app.js';
import { createAccessToken } from '../../lib/session-tokens.js';

describe('household route boundaries', () => {
  it('requires bearer auth for household lists', async () => {
    const app = buildApp();
    try {
      const response = await app.inject({ method: 'GET', url: '/v1/households' });
      expect(response.statusCode).toBe(401);
      expect(response.json()).toEqual({
        code: 'unauthorized',
        message: 'Authentication required',
      });
    } finally {
      await app.close();
    }
  });

  it('validates household create payload before touching storage', async () => {
    const app = buildApp();
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/households',
        headers: { authorization: `Bearer ${token}` },
        payload: { name: '   ' },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({
        code: 'validation_failed',
        message: 'Request validation failed',
      });
    } finally {
      await app.close();
    }
  });

  it('requires bearer auth for invite lists', async () => {
    const app = buildApp();
    try {
      const response = await app.inject({ method: 'GET', url: '/v1/household-invites' });
      expect(response.statusCode).toBe(401);
    } finally {
      await app.close();
    }
  });
});
