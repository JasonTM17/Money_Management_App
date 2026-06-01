import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { badRequest, conflict } from '../../lib/api-error.js';
import { serializeBigInts } from '../../lib/finance-serializers.js';
import { InMemoryRateLimiter, rateLimitKey } from '../../lib/rate-limiter.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';
import { recordSyncEventWithPrisma, serializeSyncEvent } from './sync-event-service.js';

const changesQuerySchema = z.object({
  since: z.string().datetime().optional(),
});

const walletTypeSchema = z.enum(['cash', 'bank', 'eWallet', 'creditCard']);
const financeTypeSchema = z.enum(['income', 'expense', 'transfer']);

const walletCreatePayloadSchema = z
  .object({
    name: z.string().trim().min(1),
    type: walletTypeSchema,
    initialBalance: z.number().int().nonnegative(),
  })
  .strict();
const walletUpdatePayloadSchema = walletCreatePayloadSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

const categoryCreatePayloadSchema = z
  .object({
    name: z.string().trim().min(1),
    type: financeTypeSchema,
    colorHex: z.number().int(),
  })
  .strict();
const categoryUpdatePayloadSchema = categoryCreatePayloadSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

const transactionCreatePayloadSchema = z
  .object({
    walletId: z.string().uuid(),
    toWalletId: z.string().uuid().nullable().optional(),
    categoryId: z.string().uuid(),
    type: financeTypeSchema,
    amount: z.number().int().positive(),
    date: z.string().datetime(),
    note: z.string(),
    isRecurring: z.boolean(),
  })
  .strict();
const transactionUpdatePayloadSchema = transactionCreatePayloadSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

const budgetCreatePayloadSchema = z
  .object({
    categoryId: z.string().uuid(),
    month: z.string().date().refine(isFirstDayDateOnly, 'Budget month must be first day'),
    limitAmount: z.number().int().positive(),
  })
  .strict();
const budgetUpdatePayloadSchema = budgetCreatePayloadSchema.partial().refine(
  (value) => Object.keys(value).length > 0,
  'At least one field is required',
);

const savingGoalPayloadBaseSchema = z
  .object({
    name: z.string().trim().min(1),
    targetAmount: z.number().int().positive(),
    savedAmount: z.number().int().nonnegative(),
    deadline: z.string().date(),
  })
  .strict();
const savingGoalCreatePayloadSchema = savingGoalPayloadBaseSchema.refine(
  (value) => value.savedAmount <= value.targetAmount,
  'Saved amount must not exceed target amount',
);
const savingGoalUpdatePayloadSchema = savingGoalPayloadBaseSchema
  .partial()
  .refine((value) => Object.keys(value).length > 0, 'At least one field is required')
  .refine(
    (value) =>
      value.targetAmount === undefined ||
      value.savedAmount === undefined ||
      value.savedAmount <= value.targetAmount,
    'Saved amount must not exceed target amount',
  );

const emptyPayloadSchema = z.object({}).strict().default({});
const mutationBaseShape = {
  clientMutationId: z.string().trim().min(1).max(120),
  entityId: z.string().uuid(),
};
const mutationBaseRevisionSchema = z.number().int().nonnegative();

type SyncEntityType = 'wallet' | 'category' | 'transaction' | 'budget' | 'savingGoal';

function createMutationSchema<const T extends SyncEntityType, P extends z.ZodTypeAny>(
  entityType: T,
  payload: P,
) {
  return z.object({
    ...mutationBaseShape,
    entityType: z.literal(entityType),
    operation: z.literal('create'),
    baseRevision: mutationBaseRevisionSchema.nullable().optional(),
    payload,
  });
}

function updateMutationSchema<const T extends SyncEntityType, P extends z.ZodTypeAny>(
  entityType: T,
  payload: P,
) {
  return z.object({
    ...mutationBaseShape,
    entityType: z.literal(entityType),
    operation: z.literal('update'),
    baseRevision: mutationBaseRevisionSchema,
    payload,
  });
}

function deleteMutationSchema<const T extends SyncEntityType>(entityType: T) {
  return z.object({
    ...mutationBaseShape,
    entityType: z.literal(entityType),
    operation: z.literal('delete'),
    baseRevision: mutationBaseRevisionSchema,
    payload: emptyPayloadSchema,
  });
}

const walletMutationSchema = z.discriminatedUnion('operation', [
  createMutationSchema('wallet', walletCreatePayloadSchema),
  updateMutationSchema('wallet', walletUpdatePayloadSchema),
  deleteMutationSchema('wallet'),
]);
const categoryMutationSchema = z.discriminatedUnion('operation', [
  createMutationSchema('category', categoryCreatePayloadSchema),
  updateMutationSchema('category', categoryUpdatePayloadSchema),
  deleteMutationSchema('category'),
]);
const transactionMutationSchema = z.discriminatedUnion('operation', [
  createMutationSchema('transaction', transactionCreatePayloadSchema),
  updateMutationSchema('transaction', transactionUpdatePayloadSchema),
  deleteMutationSchema('transaction'),
]);
const budgetMutationSchema = z.discriminatedUnion('operation', [
  createMutationSchema('budget', budgetCreatePayloadSchema),
  updateMutationSchema('budget', budgetUpdatePayloadSchema),
  deleteMutationSchema('budget'),
]);
const savingGoalMutationSchema = z.discriminatedUnion('operation', [
  createMutationSchema('savingGoal', savingGoalCreatePayloadSchema),
  updateMutationSchema('savingGoal', savingGoalUpdatePayloadSchema),
  deleteMutationSchema('savingGoal'),
]);

const syncMutationSchema = z.union([
  walletMutationSchema,
  categoryMutationSchema,
  transactionMutationSchema,
  budgetMutationSchema,
  savingGoalMutationSchema,
]);

export const syncPushSchema = z.object({
  mutations: z.array(syncMutationSchema).max(100),
});

function isFirstDayDateOnly(value: string) {
  const parsed = new Date(`${value}T00:00:00.000Z`);
  return !Number.isNaN(parsed.getTime()) && parsed.getUTCDate() === 1;
}
export async function registerSyncRoutes(app: FastifyInstance) {
  const syncPushLimiter = new InMemoryRateLimiter({
    windowMs: 60_000,
    maxAttempts: 30,
    message: 'Too many sync push requests',
  });

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
    syncPushLimiter.check(rateLimitKey(request, 'sync-push', auth.sub));
    const input = parseBody(syncPushSchema, request.body);
    const duplicates: SyncDuplicateMutation[] = [];
    const conflicts: SyncConflict[] = [];
    const pendingMutations: SyncMutation[] = [];

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
        duplicates.push({ clientMutationId: mutation.clientMutationId, duplicate: true });
        continue;
      }

      const current = await findSyncRecord(app, auth.sub, mutation.entityType, mutation.entityId);
      if (mutation.operation === 'create' && current) {
        conflicts.push({
          clientMutationId: mutation.clientMutationId,
          entityType: mutation.entityType,
          entityId: mutation.entityId,
          server: serializeBigInts(current),
        });
        continue;
      }
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

      await validateSyncMutationForUser(app, auth.sub, mutation, current);
      pendingMutations.push(mutation);
    }

      if (conflicts.length > 0) {
        throw conflict('sync_conflict', 'One or more sync mutations conflict', {
        applied: duplicates,
          conflicts,
        });
      }

    const applied = await app.prisma.$transaction(async (tx) => {
      const results: SyncAppliedMutation[] = [];
      for (const mutation of pendingMutations) {
        const result = await applySyncMutation(tx, auth.sub, mutation);
        await recordSyncEventWithPrisma(
          tx,
          auth.sub,
          mutation.entityType,
          mutation.operation,
          result,
        );
        await tx.clientMutation.create({
          data: {
            userId: auth.sub,
            clientMutationId: mutation.clientMutationId,
          },
        });
        results.push({
          clientMutationId: mutation.clientMutationId,
          entityType: mutation.entityType,
          entityId: result.id,
          record: serializeBigInts(result),
        });
      }
      return results;
    });

    return { applied: [...duplicates, ...applied], conflicts };
  });
}

type SyncMutation = Omit<z.infer<typeof syncMutationSchema>, 'payload'> & {
  payload: Record<string, unknown>;
};
type SyncRecord = Record<string, unknown> & { revision?: bigint | number | null };
type SyncDuplicateMutation = {
  clientMutationId: string;
  duplicate: true;
};

type SyncConflict = {
  clientMutationId: string;
  entityType: SyncMutation['entityType'];
  entityId: string;
  server: Record<string, unknown> | null;
};

type SyncAppliedMutation = {
  clientMutationId: string;
  entityType: SyncMutation['entityType'];
  entityId: string;
  record: Record<string, unknown>;
};

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

export async function validateSyncMutationForUser(
  app: Pick<FastifyInstance, 'prisma'>,
  userId: string,
  mutation: SyncMutation,
  current: SyncRecord | null,
) {
  if (mutation.operation === 'delete') {
    switch (mutation.entityType) {
      case 'wallet':
        await assertWalletHasNoActiveDependents(app, userId, mutation.entityId);
        return;
      case 'category':
        await assertCategoryHasNoActiveDependents(app, userId, mutation.entityId);
        return;
      case 'transaction':
      case 'budget':
      case 'savingGoal':
        return;
    }
  }
  switch (mutation.entityType) {
    case 'wallet':
      return;
    case 'category':
      if (
        mutation.operation === 'update' &&
        hasPayloadKey(mutation, 'type') &&
        current?.type !== mutation.payload.type
      ) {
        await assertCategoryHasNoActiveDependents(app, userId, mutation.entityId);
      }
      return;
    case 'budget': {
      const categoryId = stringPayloadOrCurrent(mutation, current, 'categoryId');
      await assertExpenseCategory(app, userId, categoryId);
      return;
    }
    case 'savingGoal': {
      const targetAmount = numberPayloadOrCurrent(mutation, current, 'targetAmount');
      const savedAmount = numberPayloadOrCurrent(mutation, current, 'savedAmount');
      if (savedAmount > targetAmount) {
        throw badRequest('invalid_sync_payload', 'Saved amount cannot exceed target amount');
      }
      return;
    }
    case 'transaction': {
      const walletId = stringPayloadOrCurrent(mutation, current, 'walletId');
      const toWalletId = nullableStringPayloadOrCurrent(mutation, current, 'toWalletId');
      const categoryId = stringPayloadOrCurrent(mutation, current, 'categoryId');
      const type = financeTypePayloadOrCurrent(mutation, current);
      await assertWalletBelongsToUser(app, userId, walletId);
      if (type === 'transfer' && !toWalletId) {
        throw badRequest('transfer_target_required', 'Transfer target wallet is required');
      }
      if (toWalletId) {
        if (toWalletId === walletId) {
          throw badRequest('invalid_transfer_target', 'Transfer target must be different');
        }
        await assertWalletBelongsToUser(app, userId, toWalletId);
      }
      if (type !== 'transfer' && toWalletId) {
        throw badRequest(
          'transfer_target_not_allowed',
          'Income and expense transactions cannot have a transfer target',
        );
      }
      const categoryType = await getCategoryTypeForUser(app, userId, categoryId);
      if (categoryType !== type) {
        throw badRequest('category_type_mismatch', 'Category type must match transaction type');
      }
      return;
    }
  }
}

type SyncMutationWriter = Pick<FastifyInstance['prisma'], 'wallet' | 'category' | 'budget' | 'savingGoal' | 'transaction'>;

async function applySyncMutation(
  prisma: SyncMutationWriter,
  userId: string,
  mutation: SyncMutation,
) {
  const deletedAt = mutation.operation === 'delete' ? new Date() : null;
  switch (mutation.entityType) {
    case 'wallet':
      if (mutation.operation === 'create') {
        return prisma.wallet.create({
          data: {
            id: mutation.entityId,
            userId,
            name: stringPayload(mutation, 'name'),
            type: walletTypePayload(mutation),
            initialBalance: BigInt(numberPayload(mutation, 'initialBalance')),
          },
        });
      }
      return prisma.wallet.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : walletUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'category':
      if (mutation.operation === 'create') {
        return prisma.category.create({
          data: {
            id: mutation.entityId,
            userId,
            name: stringPayload(mutation, 'name'),
            type: financeTypePayload(mutation),
            colorHex: numberPayload(mutation, 'colorHex'),
          },
        });
      }
      return prisma.category.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : categoryUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'budget':
      if (mutation.operation === 'create') {
        return prisma.budget.create({
          data: {
            id: mutation.entityId,
            userId,
            categoryId: stringPayload(mutation, 'categoryId'),
            month: new Date(stringPayload(mutation, 'month')),
            limitAmount: BigInt(numberPayload(mutation, 'limitAmount')),
          },
        });
      }
      return prisma.budget.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : budgetUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'savingGoal':
      if (mutation.operation === 'create') {
        return prisma.savingGoal.create({
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
      return prisma.savingGoal.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : savingGoalUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
    case 'transaction':
      if (mutation.operation === 'create') {
        return prisma.transaction.create({
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
      return prisma.transaction.update({
        where: { id: mutation.entityId },
        data: {
          ...(mutation.operation === 'delete' ? { deletedAt } : transactionUpdatePayload(mutation)),
          revision: { increment: 1 },
        },
      });
  }
}

function hasPayloadKey(mutation: SyncMutation, key: string) {
  return Object.prototype.hasOwnProperty.call(mutation.payload, key);
}

function currentValue(current: SyncRecord | null, key: string) {
  if (!current || current[key] === undefined) {
    throw badRequest('invalid_sync_payload', `${key} is required`);
  }
  return current[key];
}

function stringPayload(mutation: SyncMutation, key: string) {
  const value = mutation.payload[key];
  if (typeof value !== 'string') {
    throw badRequest('invalid_sync_payload', `${key} is required`);
  }
  return value;
}

function stringPayloadOrCurrent(mutation: SyncMutation, current: SyncRecord | null, key: string) {
  const value = hasPayloadKey(mutation, key) ? mutation.payload[key] : currentValue(current, key);
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

function nullableStringPayloadOrCurrent(mutation: SyncMutation, current: SyncRecord | null, key: string) {
  const value = hasPayloadKey(mutation, key) ? mutation.payload[key] : current?.[key] ?? null;
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

function numberPayloadOrCurrent(mutation: SyncMutation, current: SyncRecord | null, key: string) {
  const value = hasPayloadKey(mutation, key) ? mutation.payload[key] : currentValue(current, key);
  if (typeof value === 'bigint') return Number(value);
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

function financeTypePayloadOrCurrent(mutation: SyncMutation, current: SyncRecord | null) {
  const value = hasPayloadKey(mutation, 'type') ? mutation.payload.type : currentValue(current, 'type');
  if (!['income', 'expense', 'transfer'].includes(String(value))) {
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

async function assertWalletBelongsToUser(
  app: Pick<FastifyInstance, 'prisma'>,
  userId: string,
  walletId: string,
) {
  const wallet = await app.prisma.wallet.findFirst({
    where: { id: walletId, userId, deletedAt: null },
    select: { id: true },
  });
  if (!wallet) throw badRequest('invalid_wallet', 'Wallet does not exist');
}

async function getCategoryTypeForUser(
  app: Pick<FastifyInstance, 'prisma'>,
  userId: string,
  categoryId: string,
) {
  const category = await app.prisma.category.findFirst({
    where: { id: categoryId, userId, deletedAt: null },
    select: { type: true },
  });
  if (!category) throw badRequest('invalid_category', 'Category does not exist');
  return category.type;
}

async function assertExpenseCategory(
  app: Pick<FastifyInstance, 'prisma'>,
  userId: string,
  categoryId: string,
) {
  const categoryType = await getCategoryTypeForUser(app, userId, categoryId);
  if (categoryType !== 'expense') {
    throw badRequest('budget_category_must_be_expense', 'Budget category must be an expense category');
  }
}

async function assertWalletHasNoActiveDependents(
  app: Pick<FastifyInstance, 'prisma'>,
  userId: string,
  walletId: string,
) {
  const count = await app.prisma.transaction.count({
    where: {
      userId,
      deletedAt: null,
      OR: [{ walletId }, { toWalletId: walletId }],
    },
  });
  if (count > 0) {
    throw badRequest('wallet_has_transactions', 'Wallet has active transactions');
  }
}

async function assertCategoryHasNoActiveDependents(
  app: Pick<FastifyInstance, 'prisma'>,
  userId: string,
  categoryId: string,
) {
  const [transactions, budgets] = await Promise.all([
    app.prisma.transaction.count({ where: { userId, categoryId, deletedAt: null } }),
    app.prisma.budget.count({ where: { userId, categoryId, deletedAt: null } }),
  ]);
  if (transactions + budgets > 0) {
    throw badRequest('category_has_dependents', 'Category has active transactions or budgets');
  }
}
