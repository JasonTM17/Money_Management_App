import type { FastifyInstance } from 'fastify';
import { serializeBigInts } from '../../lib/finance-serializers.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';
import {
  idParamSchema,
  sharedBudgetParamSchema,
  sharedBudgetPatchSchema,
  sharedBudgetSchema,
} from './household-schemas.js';
import {
  ensureCategoryOwnership,
  ensureSharedBudget,
  recordHouseholdSyncEvent,
  requireMember,
  requireOwner,
} from './household-service.js';

export async function registerSharedBudgetRoutes(app: FastifyInstance) {
  app.get('/v1/households/:id/shared-budgets', async (request) => {
    const auth = requireAuth(request);
    const params = idParamSchema.parse(request.params);
    await requireMember(app, auth.sub, params.id);
    const budgets = await app.prisma.sharedBudget.findMany({
      where: { householdId: params.id, deletedAt: null },
      orderBy: [{ month: 'desc' }, { createdAt: 'desc' }],
    });
    return budgets.map(serializeBigInts);
  });

  app.post('/v1/households/:id/shared-budgets', async (request, reply) => {
    const auth = requireAuth(request);
    const params = idParamSchema.parse(request.params);
    const input = parseBody(sharedBudgetSchema, request.body);
    await requireOwner(app, auth.sub, params.id);
    await ensureCategoryOwnership(app, auth.sub, input.categoryId);
    const budget = await app.prisma.sharedBudget.create({
      data: {
        householdId: params.id,
        name: input.name,
        categoryId: input.categoryId,
        month: new Date(input.month),
        limitAmount: BigInt(input.limitAmount),
      },
    });
    await recordHouseholdSyncEvent(app, params.id, 'create', budget);
    return reply.status(201).send(serializeBigInts(budget));
  });

  app.patch('/v1/households/:householdId/shared-budgets/:budgetId', async (request) => {
    const auth = requireAuth(request);
    const params = sharedBudgetParamSchema.parse(request.params);
    const input = parseBody(sharedBudgetPatchSchema, request.body);
    await requireOwner(app, auth.sub, params.householdId);
    await ensureCategoryOwnership(app, auth.sub, input.categoryId);
    await ensureSharedBudget(app, params.householdId, params.budgetId);
    const budget = await app.prisma.sharedBudget.update({
      where: { id: params.budgetId },
      data: {
        ...(input.name === undefined ? {} : { name: input.name }),
        ...(input.categoryId === undefined ? {} : { categoryId: input.categoryId }),
        ...(input.month === undefined ? {} : { month: new Date(input.month) }),
        ...(input.limitAmount === undefined ? {} : { limitAmount: BigInt(input.limitAmount) }),
        revision: { increment: 1 },
      },
    });
    await recordHouseholdSyncEvent(app, params.householdId, 'update', budget);
    return serializeBigInts(budget);
  });

  app.delete('/v1/households/:householdId/shared-budgets/:budgetId', async (request) => {
    const auth = requireAuth(request);
    const params = sharedBudgetParamSchema.parse(request.params);
    await requireOwner(app, auth.sub, params.householdId);
    await ensureSharedBudget(app, params.householdId, params.budgetId);
    const budget = await app.prisma.sharedBudget.update({
      where: { id: params.budgetId },
      data: { deletedAt: new Date(), revision: { increment: 1 } },
    });
    await recordHouseholdSyncEvent(app, params.householdId, 'delete', budget);
    return serializeBigInts(budget);
  });
}
