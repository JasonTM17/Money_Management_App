import type { FastifyInstance } from 'fastify';
import { badRequest, notFound } from '../../lib/api-error.js';
import { serializeBigInts } from '../../lib/finance-serializers.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';
import { recordSyncEvent } from '../sync/sync-event-service.js';
import {
  budgetPatchSchema,
  budgetSchema,
  categoryPatchSchema,
  categorySchema,
  idParamSchema,
  savingGoalPatchSchema,
  savingGoalSchema,
  transactionPatchSchema,
  transactionQuerySchema,
  transactionSchema,
  walletPatchSchema,
  walletSchema,
} from './finance-schemas.js';

export async function registerFinanceRoutes(app: FastifyInstance) {
  app.get('/v1/wallets', async (request) => {
    const auth = requireAuth(request);
    const wallets = await app.prisma.wallet.findMany({
      where: { userId: auth.sub, deletedAt: null },
      orderBy: { createdAt: 'asc' },
    });
    return wallets.map(serializeBigInts);
  });

  app.post('/v1/wallets', async (request, reply) => {
    const auth = requireAuth(request);
    const input = parseBody(walletSchema, request.body);
    const wallet = await app.prisma.wallet.create({
      data: {
        ...input,
        userId: auth.sub,
        initialBalance: BigInt(input.initialBalance),
      },
    });
    await recordSyncEvent(app, auth.sub, 'wallet', 'create', wallet);
    return reply.status(201).send(serializeBigInts(wallet));
  });

  app.patch('/v1/wallets/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    const input = parseBody(walletPatchSchema, request.body);
    await assertWalletBelongsToUser(app, auth.sub, id);
    const wallet = await app.prisma.wallet.update({
      where: { id },
      data: {
        ...(input.name === undefined ? {} : { name: input.name }),
        ...(input.type === undefined ? {} : { type: input.type }),
        ...(input.initialBalance === undefined
          ? {}
          : { initialBalance: BigInt(input.initialBalance) }),
        revision: { increment: 1 },
      },
    });
    await recordSyncEvent(app, auth.sub, 'wallet', 'update', wallet);
    return serializeBigInts(wallet);
  });

  app.delete('/v1/wallets/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    await assertWalletBelongsToUser(app, auth.sub, id);
    const wallet = await app.prisma.wallet.update({
      where: { id },
      data: { deletedAt: new Date(), revision: { increment: 1 } },
    });
    await recordSyncEvent(app, auth.sub, 'wallet', 'delete', wallet);
    return serializeBigInts(wallet);
  });

  app.get('/v1/categories', async (request) => {
    const auth = requireAuth(request);
    const categories = await app.prisma.category.findMany({
      where: { userId: auth.sub, deletedAt: null },
      orderBy: { createdAt: 'asc' },
    });
    return categories.map(serializeBigInts);
  });

  app.post('/v1/categories', async (request, reply) => {
    const auth = requireAuth(request);
    const input = parseBody(categorySchema, request.body);
    const category = await app.prisma.category.create({
      data: { ...input, userId: auth.sub },
    });
    await recordSyncEvent(app, auth.sub, 'category', 'create', category);
    return reply.status(201).send(serializeBigInts(category));
  });

  app.patch('/v1/categories/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    const input = parseBody(categoryPatchSchema, request.body);
    await assertCategoryBelongsToUser(app, auth.sub, id);
    const category = await app.prisma.category.update({
      where: { id },
      data: { ...input, revision: { increment: 1 } },
    });
    await recordSyncEvent(app, auth.sub, 'category', 'update', category);
    return serializeBigInts(category);
  });

  app.delete('/v1/categories/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    await assertCategoryBelongsToUser(app, auth.sub, id);
    const category = await app.prisma.category.update({
      where: { id },
      data: { deletedAt: new Date(), revision: { increment: 1 } },
    });
    await recordSyncEvent(app, auth.sub, 'category', 'delete', category);
    return serializeBigInts(category);
  });

  app.get('/v1/transactions', async (request) => {
    const auth = requireAuth(request);
    const query = transactionQuerySchema.safeParse(request.query);
    if (!query.success) {
      throw badRequest('validation_failed', 'Request validation failed', {
        issues: query.error.flatten(),
      });
    }
    const month = query.data.month;
    const where = month
      ? {
          userId: auth.sub,
          deletedAt: null,
          date: {
            gte: new Date(`${month}T00:00:00.000Z`),
            lt: new Date(
              Date.UTC(
                Number.parseInt(month.slice(0, 4), 10),
                Number.parseInt(month.slice(5, 7), 10),
                1,
              ),
            ),
          },
        }
      : { userId: auth.sub, deletedAt: null };
    const transactions = await app.prisma.transaction.findMany({
      where,
      orderBy: { date: 'desc' },
    });
    return transactions.map(serializeBigInts);
  });

  app.post('/v1/transactions', async (request, reply) => {
    const auth = requireAuth(request);
    const input = parseBody(transactionSchema, request.body);
    await validateTransactionInput(app, auth.sub, input);
    const transaction = await app.prisma.transaction.create({
      data: {
        ...input,
        userId: auth.sub,
        amount: BigInt(input.amount),
        date: new Date(input.date),
        toWalletId: input.toWalletId ?? null,
      },
    });
    await recordSyncEvent(app, auth.sub, 'transaction', 'create', transaction);
    return reply.status(201).send(serializeBigInts(transaction));
  });

  app.patch('/v1/transactions/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    const input = parseBody(transactionPatchSchema, request.body);
    const current = await getTransactionForUser(app, auth.sub, id);
    const merged = {
      walletId: input.walletId ?? current.walletId,
      toWalletId: input.toWalletId ?? current.toWalletId,
      categoryId: input.categoryId ?? current.categoryId,
      type: input.type ?? current.type,
      amount: input.amount ?? Number(current.amount),
      date: input.date ?? current.date.toISOString(),
      note: input.note ?? current.note,
      isRecurring: input.isRecurring ?? current.isRecurring,
    };
    await validateTransactionInput(app, auth.sub, merged);
    const transaction = await app.prisma.transaction.update({
      where: { id },
      data: {
        ...merged,
        amount: BigInt(merged.amount),
        date: new Date(merged.date),
        toWalletId: merged.toWalletId ?? null,
        revision: { increment: 1 },
      },
    });
    await recordSyncEvent(app, auth.sub, 'transaction', 'update', transaction);
    return serializeBigInts(transaction);
  });

  app.delete('/v1/transactions/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    await getTransactionForUser(app, auth.sub, id);
    const transaction = await app.prisma.transaction.update({
      where: { id },
      data: { deletedAt: new Date(), revision: { increment: 1 } },
    });
    await recordSyncEvent(app, auth.sub, 'transaction', 'delete', transaction);
    return serializeBigInts(transaction);
  });

  app.get('/v1/budgets', async (request) => {
    const auth = requireAuth(request);
    const budgets = await app.prisma.budget.findMany({
      where: { userId: auth.sub, deletedAt: null },
      orderBy: { month: 'desc' },
    });
    return budgets.map(serializeBigInts);
  });

  app.post('/v1/budgets', async (request, reply) => {
    const auth = requireAuth(request);
    const input = parseBody(budgetSchema, request.body);
    await assertExpenseCategory(app, auth.sub, input.categoryId);
    const budget = await app.prisma.budget.create({
      data: {
        ...input,
        userId: auth.sub,
        limitAmount: BigInt(input.limitAmount),
        month: new Date(input.month),
      },
    });
    await recordSyncEvent(app, auth.sub, 'budget', 'create', budget);
    return reply.status(201).send(serializeBigInts(budget));
  });

  app.patch('/v1/budgets/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    const input = parseBody(budgetPatchSchema, request.body);
    await assertBudgetBelongsToUser(app, auth.sub, id);
    if (input.categoryId) await assertExpenseCategory(app, auth.sub, input.categoryId);
    const budget = await app.prisma.budget.update({
      where: { id },
      data: {
        ...(input.categoryId === undefined ? {} : { categoryId: input.categoryId }),
        ...(input.month === undefined ? {} : { month: new Date(input.month) }),
        ...(input.limitAmount === undefined
          ? {}
          : { limitAmount: BigInt(input.limitAmount) }),
        revision: { increment: 1 },
      },
    });
    await recordSyncEvent(app, auth.sub, 'budget', 'update', budget);
    return serializeBigInts(budget);
  });

  app.delete('/v1/budgets/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    await assertBudgetBelongsToUser(app, auth.sub, id);
    const budget = await app.prisma.budget.update({
      where: { id },
      data: { deletedAt: new Date(), revision: { increment: 1 } },
    });
    await recordSyncEvent(app, auth.sub, 'budget', 'delete', budget);
    return serializeBigInts(budget);
  });

  app.get('/v1/saving-goals', async (request) => {
    const auth = requireAuth(request);
    const savingGoals = await app.prisma.savingGoal.findMany({
      where: { userId: auth.sub, deletedAt: null },
      orderBy: { deadline: 'asc' },
    });
    return savingGoals.map(serializeBigInts);
  });

  app.post('/v1/saving-goals', async (request, reply) => {
    const auth = requireAuth(request);
    const input = parseBody(savingGoalSchema, request.body);
    const savingGoal = await app.prisma.savingGoal.create({
      data: {
        ...input,
        userId: auth.sub,
        targetAmount: BigInt(input.targetAmount),
        savedAmount: BigInt(input.savedAmount),
        deadline: new Date(input.deadline),
      },
    });
    await recordSyncEvent(app, auth.sub, 'savingGoal', 'create', savingGoal);
    return reply.status(201).send(serializeBigInts(savingGoal));
  });

  app.patch('/v1/saving-goals/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    const input = parseBody(savingGoalPatchSchema, request.body);
    await assertSavingGoalBelongsToUser(app, auth.sub, id);
    const savingGoal = await app.prisma.savingGoal.update({
      where: { id },
      data: {
        ...(input.name === undefined ? {} : { name: input.name }),
        ...(input.targetAmount === undefined
          ? {}
          : { targetAmount: BigInt(input.targetAmount) }),
        ...(input.savedAmount === undefined
          ? {}
          : { savedAmount: BigInt(input.savedAmount) }),
        ...(input.deadline === undefined
          ? {}
          : { deadline: new Date(input.deadline) }),
        revision: { increment: 1 },
      },
    });
    await recordSyncEvent(app, auth.sub, 'savingGoal', 'update', savingGoal);
    return serializeBigInts(savingGoal);
  });

  app.delete('/v1/saving-goals/:id', async (request) => {
    const auth = requireAuth(request);
    const { id } = parseBody(idParamSchema, request.params);
    await assertSavingGoalBelongsToUser(app, auth.sub, id);
    const savingGoal = await app.prisma.savingGoal.update({
      where: { id },
      data: { deletedAt: new Date(), revision: { increment: 1 } },
    });
    await recordSyncEvent(app, auth.sub, 'savingGoal', 'delete', savingGoal);
    return serializeBigInts(savingGoal);
  });
}

async function assertWalletBelongsToUser(
  app: FastifyInstance,
  userId: string,
  walletId: string,
) {
  const wallet = await app.prisma.wallet.findFirst({
    where: { id: walletId, userId, deletedAt: null },
    select: { id: true },
  });
  if (!wallet) throw notFound('wallet_not_found', 'Wallet does not exist');
}

async function assertCategoryBelongsToUser(
  app: FastifyInstance,
  userId: string,
  categoryId: string,
) {
  const category = await app.prisma.category.findFirst({
    where: { id: categoryId, userId, deletedAt: null },
    select: { id: true },
  });
  if (!category) throw notFound('category_not_found', 'Category does not exist');
}

async function getTransactionForUser(
  app: FastifyInstance,
  userId: string,
  transactionId: string,
) {
  const transaction = await app.prisma.transaction.findFirst({
    where: { id: transactionId, userId, deletedAt: null },
  });
  if (!transaction) {
    throw notFound('transaction_not_found', 'Transaction does not exist');
  }
  return transaction;
}

async function assertBudgetBelongsToUser(
  app: FastifyInstance,
  userId: string,
  budgetId: string,
) {
  const budget = await app.prisma.budget.findFirst({
    where: { id: budgetId, userId, deletedAt: null },
    select: { id: true },
  });
  if (!budget) throw notFound('budget_not_found', 'Budget does not exist');
}

async function assertSavingGoalBelongsToUser(
  app: FastifyInstance,
  userId: string,
  goalId: string,
) {
  const goal = await app.prisma.savingGoal.findFirst({
    where: { id: goalId, userId, deletedAt: null },
    select: { id: true },
  });
  if (!goal) throw notFound('saving_goal_not_found', 'Saving goal does not exist');
}

async function getCategoryTypeForUser(
  app: FastifyInstance,
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
  app: FastifyInstance,
  userId: string,
  categoryId: string,
) {
  const categoryType = await getCategoryTypeForUser(app, userId, categoryId);
  if (categoryType !== 'expense') {
    throw badRequest(
      'budget_category_must_be_expense',
      'Budget category must be an expense category',
    );
  }
}

async function validateTransactionInput(
  app: FastifyInstance,
  userId: string,
  input: {
    walletId: string;
    toWalletId?: string | null;
    categoryId: string;
    type: 'income' | 'expense' | 'transfer';
  },
) {
  await assertWalletBelongsToUser(app, userId, input.walletId);
  if (input.type === 'transfer' && !input.toWalletId) {
    throw badRequest('transfer_target_required', 'Transfer target wallet is required');
  }
  if (input.toWalletId) {
    if (input.toWalletId === input.walletId) {
      throw badRequest('invalid_transfer_target', 'Transfer target must be different');
    }
    await assertWalletBelongsToUser(app, userId, input.toWalletId);
  }
  const categoryType = await getCategoryTypeForUser(app, userId, input.categoryId);
  if (categoryType !== input.type) {
    throw badRequest('category_type_mismatch', 'Category type must match transaction type');
  }
}
