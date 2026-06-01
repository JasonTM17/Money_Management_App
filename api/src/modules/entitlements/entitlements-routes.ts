import type { FastifyInstance } from 'fastify';
import { requireAuth } from '../auth/auth-context.js';

export async function registerEntitlementRoutes(app: FastifyInstance) {
  app.get('/v1/entitlements/me', async (request) => {
    const auth = requireAuth(request);
    const now = new Date();
    const entitlements = await app.prisma.entitlement.findMany({
      where: { userId: auth.sub },
      orderBy: { updatedAt: 'desc' },
    });
    const premium = entitlements.some(
      (entitlement) =>
        entitlement.status === 'active' &&
        (!entitlement.currentPeriodEnd || entitlement.currentPeriodEnd > now),
    );

    return {
      premium,
      entitlements,
      lockedFeatures: premium
        ? []
        : ['cloudSync', 'sharedHouseholds', 'advancedReceiptOcr', 'advancedReports'],
    };
  });
}
