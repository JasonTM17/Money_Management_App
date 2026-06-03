import { describe, expect, it } from 'vitest';
import { buildApp } from '../../app.js';
import { createAccessToken } from '../../lib/session-tokens.js';

const DB_URL =
  'postgresql://cashflow_app:change-me-local-only@localhost:5433/cashflow_manager?schema=public';

function authHeader(sub = '00000000-0000-4000-8000-000000000001') {
  const token = createAccessToken({ sub, email: 'test@test.local' });
  return { Authorization: `Bearer ${token}` };
}

describe('finance wallets CRUD', () => {
  it('returns 401 without auth', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const res = await app.inject({ method: 'GET', url: '/v1/wallets' });
      expect(res.statusCode).toBe(401);
    } finally {
      await app.close();
    }
  });

  it('creates and lists wallets', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/wallets',
        headers: authHeader(),
        payload: { name: 'Test Wallet', type: 'cash', initialBalance: 1000000 },
      });
      expect(create.statusCode).toBe(201);
      const created = create.json();
      expect(created.name).toBe('Test Wallet');
      expect(created.type).toBe('cash');

      const list = await app.inject({
        method: 'GET',
        url: '/v1/wallets',
        headers: authHeader(),
      });
      expect(list.statusCode).toBe(200);
      expect(list.json()).toHaveLength(1);
    } finally {
      await app.close();
    }
  });

  it('rejects invalid wallet payload', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/wallets',
        headers: authHeader(),
        payload: { name: '', type: 'invalid' },
      });
      expect(res.statusCode).toBe(400);
    } finally {
      await app.close();
    }
  });

  it('updates a wallet', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/wallets',
        headers: authHeader(),
        payload: { name: 'Original', type: 'bank', initialBalance: 500000 },
      });
      const { id } = create.json();

      const patch = await app.inject({
        method: 'PATCH',
        url: `/v1/wallets/${id}`,
        headers: authHeader(),
        payload: { name: 'Renamed' },
      });
      expect(patch.statusCode).toBe(200);
      expect(patch.json().name).toBe('Renamed');
    } finally {
      await app.close();
    }
  });

  it('soft-deletes a wallet', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/wallets',
        headers: authHeader(),
        payload: { name: 'ToDelete', type: 'ewallet', initialBalance: 0 },
      });
      const { id } = create.json();

      const del = await app.inject({
        method: 'DELETE',
        url: `/v1/wallets/${id}`,
        headers: authHeader(),
      });
      expect(del.statusCode).toBe(200);

      // deleted wallets should not appear in list
      const list = await app.inject({
        method: 'GET',
        url: '/v1/wallets',
        headers: authHeader(),
      });
      expect(list.json()).toHaveLength(0);
    } finally {
      await app.close();
    }
  });
});

describe('finance categories CRUD', () => {
  it('creates and lists categories', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/categories',
        headers: authHeader(),
        payload: { name: 'Food', type: 'expense' },
      });
      expect(create.statusCode).toBe(201);

      const list = await app.inject({
        method: 'GET',
        url: '/v1/categories',
        headers: authHeader(),
      });
      expect(list.statusCode).toBe(200);
      expect(list.json().length).toBeGreaterThan(0);
    } finally {
      await app.close();
    }
  });

  it('deletes a category', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/categories',
        headers: authHeader(),
        payload: { name: 'Misc', type: 'expense' },
      });
      const { id } = create.json();

      const del = await app.inject({
        method: 'DELETE',
        url: `/v1/categories/${id}`,
        headers: authHeader(),
      });
      expect(del.statusCode).toBe(200);
    } finally {
      await app.close();
    }
  });
});

describe('finance transactions CRUD', () => {
  it('returns 401 without auth', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const res = await app.inject({ method: 'GET', url: '/v1/transactions' });
      expect(res.statusCode).toBe(401);
    } finally {
      await app.close();
    }
  });

  it('creates and queries transactions', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      // seed wallet + category first
      const wallet = await app.inject({
        method: 'POST', url: '/v1/wallets', headers: authHeader(),
        payload: { name: 'Cash', type: 'cash', initialBalance: 5000000 },
      });
      const walletId = wallet.json().id;

      const cat = await app.inject({
        method: 'POST', url: '/v1/categories', headers: authHeader(),
        payload: { name: 'Food', type: 'expense' },
      });
      const categoryId = cat.json().id;

      const create = await app.inject({
        method: 'POST',
        url: '/v1/transactions',
        headers: authHeader(),
        payload: {
          type: 'expense', walletId, categoryId,
          amount: 45000, note: 'Coffee', date: '2026-06-03',
        },
      });
      expect(create.statusCode).toBe(201);
      expect(create.json().note).toBe('Coffee');
      expect(create.json().amount).toBe(45000);

      const list = await app.inject({
        method: 'GET', url: '/v1/transactions', headers: authHeader(),
      });
      expect(list.statusCode).toBe(200);
      expect(list.json()).toHaveLength(1);
    } finally {
      await app.close();
    }
  });

  it('rejects invalid transaction payload', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const res = await app.inject({
        method: 'POST',
        url: '/v1/transactions',
        headers: authHeader(),
        payload: { type: 'invalid', amount: -100 },
      });
      expect(res.statusCode).toBe(400);
    } finally {
      await app.close();
    }
  });
});

describe('finance budgets CRUD', () => {
  it('creates and lists budgets', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const cat = await app.inject({
        method: 'POST', url: '/v1/categories', headers: authHeader(),
        payload: { name: 'Food', type: 'expense' },
      });
      const categoryId = cat.json().id;

      const create = await app.inject({
        method: 'POST',
        url: '/v1/budgets',
        headers: authHeader(),
        payload: {
          categoryId, amount: 3000000,
          month: '2026-06', warningThreshold: 80,
        },
      });
      expect(create.statusCode).toBe(201);
      expect(create.json().amount).toBe(3000000);

      const list = await app.inject({
        method: 'GET', url: '/v1/budgets', headers: authHeader(),
      });
      expect(list.statusCode).toBe(200);
      expect(list.json()).toHaveLength(1);
    } finally {
      await app.close();
    }
  });

  it('deletes a budget', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const cat = await app.inject({
        method: 'POST', url: '/v1/categories', headers: authHeader(),
        payload: { name: 'Food', type: 'expense' },
      });
      const categoryId = cat.json().id;

      const create = await app.inject({
        method: 'POST', url: '/v1/budgets', headers: authHeader(),
        payload: { categoryId, amount: 2000000, month: '2026-06' },
      });
      const { id } = create.json();

      const del = await app.inject({
        method: 'DELETE', url: `/v1/budgets/${id}`, headers: authHeader(),
      });
      expect(del.statusCode).toBe(200);
    } finally {
      await app.close();
    }
  });
});

describe('finance saving goals CRUD', () => {
  it('creates and lists saving goals', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const create = await app.inject({
        method: 'POST',
        url: '/v1/goals',
        headers: authHeader(),
        payload: {
          name: 'New Laptop', targetAmount: 15000000,
          deadline: '2026-12-31', icon: 'laptop',
        },
      });
      expect(create.statusCode).toBe(201);
      expect(create.json().name).toBe('New Laptop');
      expect(create.json().targetAmount).toBe(15000000);

      const list = await app.inject({
        method: 'GET', url: '/v1/goals', headers: authHeader(),
      });
      expect(list.statusCode).toBe(200);
      expect(list.json()).toHaveLength(1);
    } finally {
      await app.close();
    }
  });

  it('deletes a saving goal', async () => {
    const app = buildApp({ databaseUrl: DB_URL });
    try {
      const create = await app.inject({
        method: 'POST', url: '/v1/goals', headers: authHeader(),
        payload: { name: 'Vacation', targetAmount: 10000000, deadline: '2026-09-01' },
      });
      const { id } = create.json();

      const del = await app.inject({
        method: 'DELETE', url: `/v1/goals/${id}`, headers: authHeader(),
      });
      expect(del.statusCode).toBe(200);
    } finally {
      await app.close();
    }
  });
});
