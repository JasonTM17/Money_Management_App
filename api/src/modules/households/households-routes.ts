import type { FastifyInstance } from 'fastify';
import { notFound } from '../../lib/api-error.js';
import { serializeBigInts } from '../../lib/finance-serializers.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';
import { recordSyncEvent } from '../sync/sync-event-service.js';
import { householdSchema, memberParamSchema } from './household-schemas.js';
import { requireOwner } from './household-service.js';

export async function registerHouseholdRoutes(app: FastifyInstance) {
  app.get('/v1/households', async (request) => {
    const auth = requireAuth(request);
    const memberships = await app.prisma.householdMember.findMany({
      where: { userId: auth.sub, deletedAt: null, household: { deletedAt: null } },
      include: {
        household: {
          include: {
            members: {
              where: { deletedAt: null },
              include: { user: { select: { email: true } } },
            },
            sharedBudgets: { where: { deletedAt: null } },
          },
        },
      },
      orderBy: { createdAt: 'asc' },
    });
    return memberships.map((membership) =>
      serializeBigInts({ role: membership.role, household: membership.household }),
    );
  });

  app.post('/v1/households', async (request, reply) => {
    const auth = requireAuth(request);
    const input = parseBody(householdSchema, request.body);
    const household = await app.prisma.$transaction(async (tx) => {
      const created = await tx.household.create({ data: { name: input.name } });
      await tx.householdMember.create({
        data: { householdId: created.id, userId: auth.sub, role: 'owner' },
      });
      return created;
    });
    await recordSyncEvent(app, auth.sub, 'household', 'create', household);
    return reply.status(201).send(serializeBigInts(household));
  });

  app.delete('/v1/households/:householdId/members/:memberId', async (request) => {
    const auth = requireAuth(request);
    const params = memberParamSchema.parse(request.params);
    await requireOwner(app, auth.sub, params.householdId);
    const member = await app.prisma.householdMember.findFirst({
      where: { id: params.memberId, householdId: params.householdId, deletedAt: null },
    });
    if (!member || member.role === 'owner') {
      throw notFound('household_member_not_found', 'Household member not found');
    }
    await app.prisma.householdMember.update({
      where: { id: member.id },
      data: { deletedAt: new Date() },
    });
    return { removed: true };
  });
}
