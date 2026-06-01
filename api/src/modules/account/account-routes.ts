import type { FastifyInstance } from 'fastify';
import { unauthorized } from '../../lib/api-error.js';
import { requireAuth } from '../auth/auth-context.js';

export async function registerAccountRoutes(app: FastifyInstance) {
  app.get('/v1/me', async (request) => {
    const auth = requireAuth(request);
    const user = await app.prisma.user.findFirst({
      where: { id: auth.sub, deletedAt: null },
      select: { id: true, email: true, createdAt: true, updatedAt: true },
    });
    if (!user) throw unauthorized();
    return user;
  });
}
