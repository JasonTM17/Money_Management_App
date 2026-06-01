import { describe, expect, it } from 'vitest';
import { buildApp } from '../../app.js';

describe('JWKS routes', () => {
  it('publishes the EdDSA public signing key', async () => {
    const app = buildApp({
      databaseUrl: 'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
    });

    try {
      const response = await app.inject({
        method: 'GET',
        url: '/.well-known/jwks.json',
      });

      expect(response.statusCode).toBe(200);
      expect(response.json()).toMatchObject({
        keys: [
          {
            alg: 'EdDSA',
            kid: 'local-development-key',
            kty: 'OKP',
            use: 'sig',
          },
        ],
      });
    } finally {
      await app.close();
    }
  });
});
