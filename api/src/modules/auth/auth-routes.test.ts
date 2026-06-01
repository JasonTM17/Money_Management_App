import { describe, expect, it } from 'vitest';
import { buildApp } from '../../app.js';

describe('auth route boundaries', () => {
  it('rejects invalid register payloads with the API error envelope', async () => {
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/auth/register',
        payload: { email: 'bad', password: 'short' },
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

  it('requires bearer auth before returning the current user', async () => {
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });

    try {
      const response = await app.inject({ method: 'GET', url: '/v1/me' });

      expect(response.statusCode).toBe(401);
      expect(response.json()).toEqual({
        code: 'unauthorized',
        message: 'Authentication required',
      });
    } finally {
      await app.close();
    }
  });
});
