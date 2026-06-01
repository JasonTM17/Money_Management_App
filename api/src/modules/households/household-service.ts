import type { FastifyInstance } from 'fastify';
import { badRequest, forbidden, notFound } from '../../lib/api-error.js';
import { recordSyncEvent } from '../sync/sync-event-service.js';

export async function requireMember(
  app: FastifyInstance,
  userId: string,
  householdId: string,
) {
  const membership = await app.prisma.householdMember.findFirst({
    where: { userId, householdId, deletedAt: null, household: { deletedAt: null } },
  });
  if (!membership) throw notFound('household_not_found', 'Household not found');
  return membership;
}

export async function requireOwner(
  app: FastifyInstance,
  userId: string,
  householdId: string,
) {
  const membership = await requireMember(app, userId, householdId);
  if (membership.role !== 'owner') {
    throw forbidden('household_owner_required', 'Household owner role required');
  }
  return membership;
}

export async function ensureCategoryOwnership(
  app: FastifyInstance,
  userId: string,
  categoryId?: string | null,
) {
  if (!categoryId) return;
  const category = await app.prisma.category.findFirst({
    where: { id: categoryId, userId, deletedAt: null },
  });
  if (!category) throw badRequest('invalid_category', 'Category does not exist');
}

export async function ensureSharedBudget(
  app: FastifyInstance,
  householdId: string,
  budgetId: string,
) {
  const budget = await app.prisma.sharedBudget.findFirst({
    where: { id: budgetId, householdId, deletedAt: null },
  });
  if (!budget) throw notFound('shared_budget_not_found', 'Shared budget not found');
  return budget;
}

export async function recordHouseholdSyncEvent(
  app: FastifyInstance,
  householdId: string,
  operation: 'create' | 'update' | 'delete',
  record: { id: string; revision: bigint | number },
) {
  const members = await app.prisma.householdMember.findMany({
    where: { householdId, deletedAt: null },
    select: { userId: true },
  });
  await Promise.all(
    members.map((member) =>
      recordSyncEvent(app, member.userId, 'sharedBudget', operation, record),
    ),
  );
}
