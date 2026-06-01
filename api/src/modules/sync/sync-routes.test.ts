import type { FastifyInstance } from 'fastify';
import { describe, expect, it } from 'vitest';
import { syncPushSchema, validateSyncMutationForUser } from './sync-routes.js';

function fakeApp() {
  const wallets = new Map([
    ['user-1:cash', { id: 'cash' }],
    ['user-1:bank', { id: 'bank' }],
    ['user-2:other-wallet', { id: 'other-wallet' }],
  ]);
  const categories = new Map([
    ['user-1:food', { type: 'expense' }],
    ['user-1:transfer', { type: 'transfer' }],
    ['user-2:other-category', { type: 'expense' }],
  ]);
  const transactions = [
    {
      userId: 'user-1',
      walletId: 'cash',
      toWalletId: null,
      categoryId: 'food',
      deletedAt: null,
    },
  ];
  const budgets = [{ userId: 'user-1', categoryId: 'food', deletedAt: null }];
  return {
    prisma: {
      wallet: {
        findFirst: async ({ where }: { where: { id: string; userId: string } }) =>
          wallets.get(`${where.userId}:${where.id}`) ?? null,
      },
      category: {
        findFirst: async ({ where }: { where: { id: string; userId: string } }) =>
          categories.get(`${where.userId}:${where.id}`) ?? null,
      },
      transaction: {
        count: async ({
          where,
        }: {
          where: {
            userId: string;
            walletId?: string;
            toWalletId?: string;
            categoryId?: string;
            OR?: Array<{ walletId?: string; toWalletId?: string }>;
          };
        }) =>
          transactions.filter((item) => {
            if (item.userId !== where.userId || item.deletedAt !== null) return false;
            if (where.categoryId) return item.categoryId === where.categoryId;
            return where.OR?.some(
              (clause) =>
                (clause.walletId != null && item.walletId === clause.walletId) ||
                (clause.toWalletId != null && item.toWalletId === clause.toWalletId),
            ) ?? false;
          }).length,
      },
      budget: {
        count: async ({ where }: { where: { userId: string; categoryId: string } }) =>
          budgets.filter(
            (item) =>
              item.userId === where.userId &&
              item.categoryId === where.categoryId &&
              item.deletedAt === null,
          ).length,
      },
    },
  } as unknown as Pick<FastifyInstance, 'prisma'>;
}

describe('sync mutation ownership validation', () => {
  it('rejects cross-user wallet references in transaction creates', async () => {
    await expect(
      validateSyncMutationForUser(
        fakeApp(),
        'user-1',
        {
          clientMutationId: 'm-1',
          entityType: 'transaction',
          entityId: '00000000-0000-4000-8000-000000000001',
          operation: 'create',
          payload: {
            walletId: 'other-wallet',
            categoryId: 'food',
            type: 'expense',
            amount: 1000,
            date: new Date().toISOString(),
            note: 'cross-user',
            isRecurring: false,
          },
        },
        null,
      ),
    ).rejects.toMatchObject({ code: 'invalid_wallet' });
  });

  it('rejects transfer mutations with same source and target wallet', async () => {
    await expect(
      validateSyncMutationForUser(
        fakeApp(),
        'user-1',
        {
          clientMutationId: 'm-2',
          entityType: 'transaction',
          entityId: '00000000-0000-4000-8000-000000000002',
          operation: 'create',
          payload: {
            walletId: 'cash',
            toWalletId: 'cash',
            categoryId: 'transfer',
            type: 'transfer',
            amount: 1000,
            date: new Date().toISOString(),
            note: 'same-wallet',
            isRecurring: false,
          },
        },
        null,
      ),
    ).rejects.toMatchObject({ code: 'invalid_transfer_target' });
  });

  it('requires synced budgets to reference an expense category owned by the user', async () => {
    await expect(
      validateSyncMutationForUser(
        fakeApp(),
        'user-1',
        {
          clientMutationId: 'm-3',
          entityType: 'budget',
          entityId: '00000000-0000-4000-8000-000000000003',
          operation: 'create',
          payload: {
            categoryId: 'other-category',
            month: '2026-06-01',
            limitAmount: 1000,
          },
        },
        null,
      ),
    ).rejects.toMatchObject({ code: 'invalid_category' });
  });


  it('rejects sync payload keys that do not belong to the entity schema', () => {
    const result = syncPushSchema.safeParse({
      mutations: [
        {
          clientMutationId: 'm-extra',
          entityType: 'wallet',
          entityId: '00000000-0000-4000-8000-000000000006',
          operation: 'create',
          payload: {
            name: 'Cash',
            type: 'cash',
            initialBalance: 0,
            categoryId: '00000000-0000-4000-8000-000000000007',
          },
        },
      ],
    });

    expect(result.success).toBe(false);
  });

  it('requires baseRevision for update and delete mutations', () => {
    const result = syncPushSchema.safeParse({
      mutations: [
        {
          clientMutationId: 'm-no-revision',
          entityType: 'wallet',
          entityId: '00000000-0000-4000-8000-000000000008',
          operation: 'delete',
          payload: {},
        },
      ],
    });

    expect(result.success).toBe(false);
  });

  it('rejects synced budgets outside the first day of the month', () => {
    const result = syncPushSchema.safeParse({
      mutations: [
        {
          clientMutationId: 'm-budget-month',
          entityType: 'budget',
          entityId: '00000000-0000-4000-8000-000000000009',
          operation: 'create',
          payload: {
            categoryId: '00000000-0000-4000-8000-000000000010',
            month: '2026-06-02',
            limitAmount: 1000,
          },
        },
      ],
    });

    expect(result.success).toBe(false);
  });

  it('rejects income or expense sync mutations that carry a transfer target', async () => {
    await expect(
      validateSyncMutationForUser(
        fakeApp(),
        'user-1',
        {
          clientMutationId: 'm-target-not-allowed',
          entityType: 'transaction',
          entityId: '00000000-0000-4000-8000-000000000011',
          operation: 'create',
          payload: {
            walletId: 'cash',
            toWalletId: 'bank',
            categoryId: 'food',
            type: 'expense',
            amount: 1000,
            date: new Date().toISOString(),
            note: 'not-transfer',
            isRecurring: false,
          },
        },
        null,
      ),
    ).rejects.toMatchObject({ code: 'transfer_target_not_allowed' });
  });


  it('rejects category type changes while active rows depend on the category', async () => {
    await expect(
      validateSyncMutationForUser(
        fakeApp(),
        'user-1',
        {
          clientMutationId: 'm-category-type',
          entityType: 'category',
          entityId: 'food',
          operation: 'update',
          baseRevision: 1,
          payload: {
            type: 'income',
          },
        },
        { id: 'food', type: 'expense', revision: 1 },
      ),
    ).rejects.toMatchObject({ code: 'category_has_dependents' });
  });

  it('rejects wallet deletes while active transactions reference the wallet', async () => {
    await expect(
      validateSyncMutationForUser(
        fakeApp(),
        'user-1',
        {
          clientMutationId: 'm-4',
          entityType: 'wallet',
          entityId: 'cash',
          operation: 'delete',
          baseRevision: 1,
          payload: {},
        },
        { id: 'cash', revision: 1 },
      ),
    ).rejects.toMatchObject({ code: 'wallet_has_transactions' });
  });

  it('rejects category deletes while active budgets reference the category', async () => {
    await expect(
      validateSyncMutationForUser(
        fakeApp(),
        'user-1',
        {
          clientMutationId: 'm-5',
          entityType: 'category',
          entityId: 'food',
          operation: 'delete',
          baseRevision: 1,
          payload: {},
        },
        { id: 'food', revision: 1 },
      ),
    ).rejects.toMatchObject({ code: 'category_has_dependents' });
  });
});
