import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import type { PrismaClient } from '@prisma/client';
import Fastify from 'fastify';
import { handleApiError } from './lib/error-handler.js';
import { createPrismaClient } from './lib/prisma-client.js';
import { registerAccountRoutes } from './modules/account/account-routes.js';
import { registerAiRoutes } from './modules/ai/ai-routes.js';
import { registerAuthRoutes } from './modules/auth/auth-routes.js';
import { registerEntitlementRoutes } from './modules/entitlements/entitlements-routes.js';
import { registerFinanceRoutes } from './modules/finance/finance-routes.js';
import { registerHealthRoutes } from './modules/health/health-routes.js';
import { registerHouseholdInviteRoutes } from './modules/households/household-invites-routes.js';
import { registerHouseholdRoutes } from './modules/households/households-routes.js';
import { registerSharedBudgetRoutes } from './modules/households/shared-budget-routes.js';
import { registerPaymentRoutes } from './modules/payments/payments-routes.js';
import { registerSyncRoutes } from './modules/sync/sync-routes.js';
import { registerJwksRoutes } from './modules/well-known/jwks-routes.js';

declare module 'fastify' {
  interface FastifyInstance {
    prisma: PrismaClient;
  }
}

type BuildAppOptions = {
  databaseUrl?: string;
};

export function buildApp(options: BuildAppOptions = {}) {
  const app = Fastify({ logger: true });
  const databaseUrl =
    options.databaseUrl ??
    process.env.DATABASE_URL ??
    'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public';
  const prisma = createPrismaClient(databaseUrl);

  app.decorate('prisma', prisma);
  app.setErrorHandler(handleApiError);
  app.addHook('onClose', async () => {
    await prisma.$disconnect();
  });

  app.register(helmet);
  app.register(cors, { origin: false });
  app.register(registerHealthRoutes);
  app.register(registerJwksRoutes);
  app.register(registerAuthRoutes);
  app.register(registerAccountRoutes);
  app.register(registerFinanceRoutes);
  app.register(registerSyncRoutes);
  app.register(registerHouseholdRoutes);
  app.register(registerHouseholdInviteRoutes);
  app.register(registerSharedBudgetRoutes);
  app.register(registerEntitlementRoutes);
  app.register(registerPaymentRoutes);
  app.register(registerAiRoutes);

  return app;
}
