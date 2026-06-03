import { describe, expect, it } from 'vitest';
import { buildApp } from '../../app.js';

const DB_URL =
  'postgresql://cashflow_app:change-me-local-only@localhost:5433/cashflow_manager?schema=public';

describe('auth route boundaries', () => {
  it('rejects invalid register payloads with the API error envelope', async () => {
    const app = buildApp({ databaseUrl: DB_URL });

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
    const app = buildApp({ databaseUrl: DB_URL });

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

  it('returns 429 with rate_limited code when register limit is exceeded', async () => {
    const app = buildApp({ databaseUrl: DB_URL });

    try {
      const payload = {
        email: 'rate-limit-register@test.local',
        password: 'long-enough-password',
      };

      for (let i = 0; i < 3; i++) {
        const resp = await app.inject({
          method: 'POST',
          url: '/v1/auth/register',
          payload,
        });
        if (resp.statusCode === 429) break;
      }

      const response = await app.inject({
        method: 'POST',
        url: '/v1/auth/register',
        payload,
      });

      expect(response.statusCode).toBe(429);
      expect(response.json()).toMatchObject({
        code: 'rate_limited',
      });
    } finally {
      await app.close();
    }
  });

  it('returns 429 with rate_limited code when login limit is exceeded', async () => {
    const app = buildApp({ databaseUrl: DB_URL });

    try {
      const payload = {
        email: 'rate-limit-login@test.local',
        password: 'does-not-matter',
      };

      for (let i = 0; i < 5; i++) {
        await app.inject({
          method: 'POST',
          url: '/v1/auth/login',
          payload,
        });
      }

      const response = await app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload,
      });

      expect(response.statusCode).toBe(429);
      expect(response.json()).toMatchObject({
        code: 'rate_limited',
      });
    } finally {
      await app.close();
    }
  });

  it('returns 429 with rate_limited code when refresh limit is exceeded', async () => {
    const app = buildApp({ databaseUrl: DB_URL });

    try {
      const payload = { refreshToken: 'dummy-refresh-token-that-is-32-chars-min' };

      for (let i = 0; i < 10; i++) {
        await app.inject({
          method: 'POST',
          url: '/v1/auth/refresh',
          payload,
        });
      }

      const response = await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload,
      });

      expect(response.statusCode).toBe(429);
      expect(response.json()).toMatchObject({
        code: 'rate_limited',
      });
    } finally {
      await app.close();
    }
  });

  it('rejects login for soft-deleted users with user_deleted code', async () => {
    const app = buildApp({ databaseUrl: DB_URL });

    try {
      const testEmail = `deleted-user-${Date.now()}@test.local`;
      const password = 'test-password-123';

      const registerResp = await app.inject({
        method: 'POST',
        url: '/v1/auth/register',
        payload: { email: testEmail, password },
      });
      expect(registerResp.statusCode).toBe(201);
      const { user } = registerResp.json();

      const loginBefore = await app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload: { email: testEmail, password },
      });
      expect(loginBefore.statusCode).toBe(200);

      const refreshToken = loginBefore.json().refreshToken;
      const refreshBefore = await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload: { refreshToken },
      });
      expect(refreshBefore.statusCode).toBe(200);

      await app.prisma.user.update({
        where: { id: user.id },
        data: { deletedAt: new Date() },
      });

      const loginAfter = await app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload: { email: testEmail, password },
      });
      expect(loginAfter.statusCode).toBe(401);
      expect(loginAfter.json()).toMatchObject({
        code: 'user_deleted',
        message: 'Account has been deleted',
      });

      const refreshAfter = await app.inject({
        method: 'POST',
        url: '/v1/auth/refresh',
        payload: { refreshToken },
      });
      expect(refreshAfter.statusCode).toBe(401);
      expect(refreshAfter.json()).toMatchObject({
        code: 'user_deleted',
        message: 'Account has been deleted',
      });
    } finally {
      await app.close();
    }
  });

  it('redacts sensitive fields in auth logs', async () => {
    const app = buildApp({ databaseUrl: DB_URL });

    try {
      const logs: string[] = [];
      const logger = {
        level: 'trace' as const,
        info: (msg: unknown) => logs.push(typeof msg === 'string' ? msg : JSON.stringify(msg)),
        warn: (msg: unknown) => logs.push(typeof msg === 'string' ? msg : JSON.stringify(msg)),
        error: (msg: unknown) => logs.push(typeof msg === 'string' ? msg : JSON.stringify(msg)),
        fatal: (msg: unknown) => logs.push(typeof msg === 'string' ? msg : JSON.stringify(msg)),
        trace: (msg: unknown) => logs.push(typeof msg === 'string' ? msg : JSON.stringify(msg)),
        debug: (msg: unknown) => logs.push(typeof msg === 'string' ? msg : JSON.stringify(msg)),
        child: () => logger,
      };

      (app as unknown as Record<string, unknown>).logger = logger;

      await app.inject({
        method: 'POST',
        url: '/v1/auth/login',
        payload: {
          email: 'redaction-test@test.local',
          password: 'super-secret-password-12345',
        },
      });

      const logText = logs.join(' ');
      expect(logText).not.toContain('super-secret-password-12345');
      expect(logText).not.toContain('Bearer ');
    } finally {
      await app.close();
    }
  });
});
