import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest, conflict } from '../../lib/api-error.js';
import { serializeBigInts } from '../../lib/finance-serializers.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';
import { recordSyncEvent, serializeSyncEvent } from './sync-event-service.js';

const changesQuerySchema = z.object({
  since: z.string().datetime().optional(),
});

const syncPayloadSchema = z
  .object({
    name: z.string().trim().min(1).optional(),
    type: z.enum(['cash', 'bank', 'eWallet', 'creditCard', 'income', 'expense', 'transfer']).optional(),
    initialBalance: z.number().int().nonnegative().optional(),
    colorHex: z.number().int().optional(),
    walletId: z.string().uuid().optional(),
    toWalletId: z.string().uuid().nullable().optional(),
    categoryId: z.string().uuid().optional(),
    amount: z.number().int().positive().optional(),
    date: z.string().datetime().optional(),
    note: z.string().optional(),
    isRecurring: z.boolean().optional(),
    month: z.string().date().optional(),
    limitAmount: z.number().int().positive().optional(),
    targetAmount: z.number().int().positive().optional(),
    savedAmount: z.number().int().nonnegative().optional(),
    deadline: z.string().date().optional(),
  })
  .passthrough();

const syncMutationSchema = z.object({
  clientMutationId: z.string().trim().min(1).max(120),
  entityType: z.enum(['wallet', 'category', 'transaction', 'budget', 'savingGoal']),
  entityId: z.string().uuid(),
  operation: z.enum(['create', 'update', 'delete']),
  baseRevision: z.number().int().nonnegative().nullable().optional(),
  payload: syncPayloadSchema.default({}),
});

const syncPushSchema = z.object({
  mutations: z.array(syncMutationSchema).max(100),
});

export async function registerSyncRoutes(app: FastifyInstance) {
  app.get('/v1/sync/bootstrap', async (request) => {
    const auth = requireAuth(request);
    const [wallets, categories, transactions, budgets, savingGoals] = await Promise.all([
      app.prisma.wallet.findMany({ where: { userId: auth.sub, deletedAt: null } }),
      app.prisma.category.findMany({ where: { userId: auth.sub, deletedAt: null } }),
      app.prisma.transaction.findMany({ where: { userId: auth.sub, deletedAt: null } }),
      app.prisma.budget.findMany({ where: { userId: auth.sub, deletedAt: null } }),
      app.prisma.savingGoal.findMany({ where: { userId: auth.sub, deletedAt: null } }),
    ]);

    return {
      cursor: new Date().toISOString(),
      wallets: wallets.map(serializeBigInts),
      categories: categories.map(serializeBigInts),
      transactions: transactions.map(serializeBigInts),
      budgets: budgets.map(serializeBigInts),
      savingGoals: savingGoals.map(serializeBigInts),
    };
  });

  app.get('/v1/sync/changes', async (request) => {
    const auth = requireAuth(request);
    const query = changesQuerySchema.safeParse(request.query);
    if (!query.success) {
      throw badRequest('validation_failed', 'Request validation failed', {
        issues: query.error.flatten(),
      });
    }
    const since = query.data.since ? new Date(query.data.since) : new Date(0);
    const events = await app.prisma.syncEvent.findMany({
      where: { userId: auth.sub, occurredAt: { gt: since } },
      orderBy: { occurredAt: 'asc' },
      take: 500,
    });
    return {
      cursor: new Date().toISOString(),
      changes: events.map(serializeSyncEvent),
    };
  });

  app.post('/v1/sync/push', async (request) => {
    const auth = requireAuth(request);
    const input = parseBody(syncPushSchema, request.body);
    const applied = [];
    const conflicts = [];

    for (const mutation of input.mutations) {
      const existingMutation = await app.prisma.clientMutation.findUnique({
        where: {
          userId_clientMutationId: {
            userId: auth.sub,
            clientMutationId: mutation.clientMutationId,
          },
        },
      });
      if (existingMutation) {
        applied.push({
          clientMutationId: mutation.clientMutationId,
          duplicate: true,
        });
        continue;
      }

      const current = await findSyncRecord(app, auth.sub, mutation.entityType, mutation.entityId);
      if (
        mutation.operation !== 'create' &&
        (!current || Number(current.revision) !== mutation.baseRevision)
      ) {
        conflicts.push({
          clientMutationId: mutation.clientMutationId,
          entityType: mutation.entityType,
          entityId: mutation.entityId,
          server: current ? serializeBigInts(current) : null,
        });
        continue;
      }

      const result = await applySyncMutation(app, auth.sub, mutation);
      await recordSyncEvent(
        app,
        auth.sub,
        mutation.entityType,
        mutation.operation,
        result,
      );
      await app.prisma.clientMutation.create({
        data: {
          userId: auth.sub,
          clientMutationId: mutation.clientMutationId,
        },
      });
      applied.push({
        clientMutationId: mutation.clientMutationId,
        entityType: mutation.entityType,
        entityId: result.id,
        record: serializeBigInts(result),
      });
    }

    if (conflicts.length > 0) {
      throw conflict('sync_conflict', 'One or more sync mutations conflict', {
        applied,
        conflicts,
      });
    }

    return { applied, conflicts };
  });
}

type SyncMutation = z.infer<typeof syncMutationSchema>;

async function findSyncRecord(
  app: FastifyInstance,
  userId: string,
  entityType: SyncMutation['entityType'],
  id: string,
) {
  switch (entityType) {
    case 'wallet':
      return app.prisma.wallet.findFirst({ where: { id, userId } });
    case 'category':
      return app.prisma.category.findFirst({ where: { id, userId } });
    case 'transaction':
      return app.prisma.transaction.findFirst({ where: { id, userId } });
    case 'budget':
      return app.prisma.budget.findFirst({ where: { id, userId } });
    case 'savingGoal':
      return app.prisma.savingGoal.findFirst({ where: { id, userId } });
  }
}

async function applySyncMutation(
  app: FastifyInstance,
  userId: string,
  mutation: SyncMutation,
) {
  const deletedAt = mutation.operation === 'delete' ? new Date() : null;
  switch (mutation.entityType) {
    case 'wallet':
      if (mutation.operation === 'create') {
        return app.prisma.wallet.create({
          data: {
            id: mutation.entityId,
            userId,
            name: stringPayload(mutation, 'name'),
            type: walletTypePayload(mutation),
            initialBalance: BigInt(numberPayload(mutation, 'initialBalance')),
          },
        });
      }
      return app.prisma.wallet.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : walletUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'category':
      if (mutation.operation === 'create') {
        return app.prisma.category.create({
          data: {
            id: mutation.entityId,
            userId,
            name: stringPayload(mutation, 'name'),
            type: financeTypePayload(mutation),
            colorHex: numberPayload(mutation, 'colorHex'),
          },
        });
      }
      return app.prisma.category.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : categoryUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'budget':
      if (mutation.operation === 'create') {
        return app.prisma.budget.create({
          data: {
            id: mutation.entityId,
            userId,
            categoryId: stringPayload(mutation, 'categoryId'),
            month: new Date(stringPayload(mutation, 'month')),
            limitAmount: BigInt(numberPayload(mutation, 'limitAmount')),
          },
        });
      }
      return app.prisma.budget.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : budgetUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'savingGoal':
      if (mutation.operation === 'create') {
        return app.prisma.savingGoal.create({
          data: {
            id: mutation.entityId,
            userId,
            name: stringPayload(mutation, 'name'),
            targetAmount: BigInt(numberPayload(mutation, 'targetAmount')),
            savedAmount: BigInt(numberPayload(mutation, 'savedAmount')),
            deadline: new Date(stringPayload(mutation, 'deadline')),
          },
        });
      }
      return app.prisma.savingGoal.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : savingGoalUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'transaction':
      if (mutation.operation === 'create') {
        return app.prisma.transaction.create({
          data: {
            id: mutation.entityId,
            userId,
            walletId: stringPayload(mutation, 'walletId'),
            toWalletId: nullableStringPayload(mutation, 'toWalletId'),
            categoryId: stringPayload(mutation, 'categoryId'),
            type: financeTypePayload(mutation),
            amount: BigInt(numberPayload(mutation, 'amount')),
            date: new Date(stringPayload(mutation, 'date')),
            note: stringPayload(mutation, 'note'),
            isRecurring: booleanPayload(mutation, 'isRecurring'),
          },
        });
      }
      return app.prisma.transaction.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : transactionUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
  }
}

function stringPayload(mutation: SyncMutation, key: string) {
  const value = mutation.payload[key];
  if (typeof value !== 'string') {
    throw badRequest('invalid_sync_payload', `${key} is required`);
  }
  return value;
}

function nullableStringPayload(mutation: SyncMutation, key: string) {
  const value = mutation.payload[key];
  if (value === null || value === undefined) return null;
  if (typeof value !== 'string') {
    throw badRequest('invalid_sync_payload', `${key} must be a string`);
  }
  return value;
}

function numberPayload(mutation: SyncMutation, key: string) {
  const value = mutation.payload[key];
  if (typeof value !== 'number') {
    throw badRequest('invalid_sync_payload', `${key} is required`);
  }
  return value;
}

function booleanPayload(mutation: SyncMutation, key: string) {
  const value = mutation.payload[key];
  if (typeof value !== 'boolean') {
    throw badRequest('invalid_sync_payload', `${key} is required`);
  }
  return value;
}

function walletTypePayload(mutation: SyncMutation) {
  const value = stringPayload(mutation, 'type');
  if (!['cash', 'bank', 'eWallet', 'creditCard'].includes(value)) {
    throw badRequest('invalid_sync_payload', 'Invalid wallet type');
  }
  return value as 'cash' | 'bank' | 'eWallet' | 'creditCard';
}

function financeTypePayload(mutation: SyncMutation) {
  const value = stringPayload(mutation, 'type');
  if (!['income', 'expense', 'transfer'].includes(value)) {
    throw badRequest('invalid_sync_payload', 'Invalid finance type');
  }
  return value as 'income' | 'expense' | 'transfer';
}

function walletUpdatePayload(mutation: SyncMutation) {
  return {
    ...(mutation.payload.name === undefined ? {} : { name: stringPayload(mutation, 'name') }),
    ...(mutation.payload.type === undefined ? {} : { type: walletTypePayload(mutation) }),
    ...(mutation.payload.initialBalance === undefined
      ? {}
      : { initialBalance: BigInt(numberPayload(mutation, 'initialBalance')) }),
  };
}

function categoryUpdatePayload(mutation: SyncMutation) {
  return {
    ...(mutation.payload.name === undefined ? {} : { name: stringPayload(mutation, 'name') }),
    ...(mutation.payload.type === undefined ? {} : { type: financeTypePayload(mutation) }),
    ...(mutation.payload.colorHex === undefined
      ? {}
      : { colorHex: numberPayload(mutation, 'colorHex') }),
  };
}

function budgetUpdatePayload(mutation: SyncMutation) {
  return {
    ...(mutation.payload.categoryId === undefined
      ? {}
      : { categoryId: stringPayload(mutation, 'categoryId') }),
    ...(mutation.payload.month === undefined
      ? {}
      : { month: new Date(stringPayload(mutation, 'month')) }),
    ...(mutation.payload.limitAmount === undefined
      ? {}
      : { limitAmount: BigInt(numberPayload(mutation, 'limitAmount')) }),
  };
}

function savingGoalUpdatePayload(mutation: SyncMutation) {
  return {
    ...(mutation.payload.name === undefined ? {} : { name: stringPayload(mutation, 'name') }),
    ...(mutation.payload.targetAmount === undefined
      ? {}
      : { targetAmount: BigInt(numberPayload(mutation, 'targetAmount')) }),
    ...(mutation.payload.savedAmount === undefined
      ? {}
      : { savedAmount: BigInt(numberPayload(mutation, 'savedAmount')) }),
    ...(mutation.payload.deadline === undefined
      ? {}
      : { deadline: new Date(stringPayload(mutation, 'deadline')) }),
  };
}

function transactionUpdatePayload(mutation: SyncMutation) {
  return {
    ...(mutation.payload.walletId === undefined
      ? {}
      : { walletId: stringPayload(mutation, 'walletId') }),
    ...(mutation.payload.toWalletId === undefined
      ? {}
      : { toWalletId: nullableStringPayload(mutation, 'toWalletId') }),
    ...(mutation.payload.categoryId === undefined
      ? {}
      : { categoryId: stringPayload(mutation, 'categoryId') }),
    ...(mutation.payload.type === undefined ? {} : { type: financeTypePayload(mutation) }),
    ...(mutation.payload.amount === undefined
      ? {}
      : { amount: BigInt(numberPayload(mutation, 'amount')) }),
    ...(mutation.payload.date === undefined
      ? {}
      : { date: new Date(stringPayload(mutation, 'date')) }),
    ...(mutation.payload.note === undefined ? {} : { note: stringPayload(mutation, 'note') }),
    ...(mutation.payload.isRecurring === undefined
      ? {}
      : { isRecurring: booleanPayload(mutation, 'isRecurring') }),
  };
}
