import { describe, expect, it } from 'vitest';
import { buildApp } from '../../app.js';

describe('health routes', () => {
  it('returns health status', async () => {
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });

    try {
      const response = await app.inject({ method: 'GET', url: '/healthz' });

      expect(response.statusCode).toBe(200);
      expect(response.json()).toEqual({ status: 'ok' });
    } finally {
      await app.close();
    }
  });

  it('returns dependency error when the database is unavailable', async () => {
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:1/cashflow_manager?schema=public',
    });

    try {
      const response = await app.inject({ method: 'GET', url: '/readyz' });

      expect(response.statusCode).toBe(503);
      expect(response.json()).toEqual({
        code: 'database_not_ready',
        message: 'Database is not migrated or unavailable',
      });
    } finally {
      await app.close();
    }
  });
});
