import type { FastifyInstance } from 'fastify';
import { forbidden, notFound } from '../../lib/api-error.js';
import { serializeBigInts } from '../../lib/finance-serializers.js';
import { createOpaqueToken, hashOpaqueToken } from '../../lib/passwords-and-tokens.js';
import { parseBody } from '../../lib/validation.js';
import { requireAuth } from '../auth/auth-context.js';
import {
  acceptInviteSchema,
  idParamSchema,
  inviteParamSchema,
  inviteSchema,
} from './household-schemas.js';
import { requireOwner } from './household-service.js';

export async function registerHouseholdInviteRoutes(app: FastifyInstance) {
  app.post('/v1/households/:id/invites', async (request, reply) => {
    const auth = requireAuth(request);
    const params = idParamSchema.parse(request.params);
    const input = parseBody(inviteSchema, request.body);
    await requireOwner(app, auth.sub, params.id);

    const invitee = await app.prisma.user.findUnique({ where: { email: input.email } });
    const token = createOpaqueToken();
    const invite = await app.prisma.householdInvite.create({
      data: {
        householdId: params.id,
        inviterId: auth.sub,
        inviteeEmail: input.email,
        inviteeId: invitee?.id,
        tokenHash: await hashOpaqueToken(token),
        expiresAt: new Date(Date.now() + input.expiresInDays * 24 * 60 * 60 * 1000),
      },
    });

    return reply.status(201).send({ ...invite, token });
  });

  app.get('/v1/household-invites', async (request) => {
    const auth = requireAuth(request);
    const user = await app.prisma.user.findFirst({
      where: { id: auth.sub, deletedAt: null },
      select: { email: true },
    });
    if (!user) throw forbidden('invite_forbidden', 'Invite cannot be listed by this user');
    return app.prisma.householdInvite.findMany({
      where: {
        inviteeEmail: user.email,
        status: 'pending',
        expiresAt: { gt: new Date() },
      },
      include: { household: true },
      orderBy: { createdAt: 'desc' },
    });
  });

  app.post('/v1/household-invites/:inviteId/accept', async (request) => {
    const auth = requireAuth(request);
    const params = inviteParamSchema.parse(request.params);
    const input = parseBody(acceptInviteSchema, request.body);
    const user = await app.prisma.user.findFirst({
      where: { id: auth.sub, deletedAt: null },
      select: { email: true },
    });
    if (!user) throw forbidden('invite_forbidden', 'Invite cannot be accepted by this user');

    const invite = await app.prisma.householdInvite.findFirst({
      where: { id: params.inviteId, status: 'pending' },
    });
    if (!invite || invite.expiresAt <= new Date()) {
      throw notFound('invite_not_found', 'Household invite not found');
    }
    if (
      invite.inviteeEmail !== user.email ||
      invite.tokenHash !== await hashOpaqueToken(input.token)
    ) {
      throw forbidden('invite_forbidden', 'Invite cannot be accepted by this user');
    }

    const membership = await app.prisma.$transaction(async (tx) => {
      const createdMembership = await tx.householdMember.upsert({
        where: {
          householdId_userId: {
            householdId: invite.householdId,
            userId: auth.sub,
          },
        },
        create: { householdId: invite.householdId, userId: auth.sub, role: 'member' },
        update: { deletedAt: null, role: 'member' },
      });
      await tx.householdInvite.update({
        where: { id: invite.id },
        data: { status: 'accepted', inviteeId: auth.sub, acceptedAt: new Date() },
      });
      return createdMembership;
    });

    return serializeBigInts(membership);
  });
}
