import { createHmac } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { buildApp } from '../../app.js';
import { resolveSePayOrderUpdate } from './payments-routes.js';
import { createAccessToken } from '../../lib/session-tokens.js';

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

describe('payment route boundaries', () => {
  it('requires bearer auth for entitlement lookup', async () => {
    const app = buildApp();
    try {
      const response = await app.inject({ method: 'GET', url: '/v1/entitlements/me' });
      expect(response.statusCode).toBe(401);
    } finally {
      await app.close();
    }
  });

  it('keeps store IAP verification closed until configured', async () => {
    const restoreEnv = snapshotEnv(['IAP_VERIFICATION_MODE']);
    process.env.IAP_VERIFICATION_MODE = 'disabled';
    const app = buildApp();
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/iap/verify',
        headers: { authorization: `Bearer ${token}` },
        payload: {
          provider: 'apple',
          productId: 'premium_monthly',
          purchaseToken: 'test-purchase-token',
        },
      });

      expect(response.statusCode).toBe(503);
      expect(response.json()).toMatchObject({ code: 'iap_verification_unconfigured' });
    } finally {
      restoreEnv();
      await app.close();
    }
  });

  it('keeps SePay orders disabled by default for store builds', async () => {
    const restoreEnv = snapshotEnv(['SEPAY_ENABLED']);
    process.env.SEPAY_ENABLED = 'false';
    const app = buildApp();
    const token = createAccessToken({
      sub: '00000000-0000-4000-8000-000000000001',
      email: 'demo@cashflow.local',
    });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/payments/sepay/orders',
        headers: { authorization: `Bearer ${token}` },
        payload: {
          plan: 'premium_monthly',
          amount: 99000,
          currency: 'VND',
          idempotencyKey: 'test-order-1',
        },
      });

      expect(response.statusCode).toBe(503);
      expect(response.json()).toMatchObject({ code: 'sepay_disabled' });
    } finally {
      restoreEnv();
      await app.close();
    }
  });


  it('prevents paid SePay orders from being downgraded by later webhook noise', () => {
    const update = resolveSePayOrderUpdate(
      { status: 'paid', amount: 99000n, paidAt: new Date('2026-06-01T00:00:00.000Z') },
      { providerOrderId: 'sepay_test', status: 'expired', amount: 99000 },
    );

    expect(update).toBeNull();
  });

  it('rejects SePay webhook amount mismatches before updating orders', () => {
    expect(() =>
      resolveSePayOrderUpdate(
        { status: 'pending', amount: 99000n, paidAt: null },
        { providerOrderId: 'sepay_test', status: 'paid', amount: 100000 },
      ),
    ).toThrowError(/Webhook amount/);
  });

  it('rejects malformed SePay webhook signatures before parsing orders', async () => {
    const restoreEnv = snapshotEnv(['SEPAY_WEBHOOK_SECRET']);
    process.env.SEPAY_WEBHOOK_SECRET = 'test-sepay-secret';
    const app = buildApp();

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/payments/sepay/webhook',
        headers: { 'x-sepay-signature': 'short' },
        payload: { providerOrderId: 'sepay_test', status: 'paid' },
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: 'invalid_sepay_signature' });
    } finally {
      restoreEnv();
      await app.close();
    }
  });

  it('rejects invalid SePay webhook signatures before mutating orders', async () => {
    const restoreEnv = snapshotEnv(['SEPAY_WEBHOOK_SECRET']);
    process.env.SEPAY_WEBHOOK_SECRET = 'test-sepay-secret';
    const app = buildApp();
    const payload = {
      providerOrderId: 'sepay_test',
      status: 'paid',
      amount: 99000,
    };

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/v1/payments/sepay/webhook',
        headers: {
          'x-sepay-signature': createHmac('sha256', 'wrong-secret')
            .update(JSON.stringify(payload))
            .digest('hex'),
        },
        payload,
      });

      expect(response.statusCode).toBe(400);
      expect(response.json()).toMatchObject({ code: 'invalid_sepay_signature' });
    } finally {
      restoreEnv();
      await app.close();
    }
  });
});
