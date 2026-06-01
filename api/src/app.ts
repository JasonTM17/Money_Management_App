import cors from '@fastify/cors';
import helmet from '@fastify/helmet';
import type { PrismaClient } from '@prisma/client';
import Fastify from 'fastify';
import { env } from './lib/env.js';
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

  interface FastifyRequest {
    rawBody?: string;
  }
}

type BuildAppOptions = {
  databaseUrl?: string;
};

export function buildApp(options: BuildAppOptions = {}) {
  const app = Fastify({
    bodyLimit: 1024 * 1024,
    logger: {
      redact: {
        paths: [
          'req.headers.authorization',
          'req.headers.cookie',
          'req.headers.x-sepay-signature',
          'req.headers.x-cashflow-signature-sha256',
          'password',
          'refreshToken',
          'accessToken',
          'purchaseToken',
          'token',
          'req.body.password',
          'req.body.refreshToken',
          'req.body.accessToken',
          'req.body.purchaseToken',
          'req.body.token',
          'req.body.providerSubscriptionId',
          '*.password',
          '*.refreshToken',
          '*.accessToken',
          '*.purchaseToken',
          '*.token',
        ],
        censor: '[REDACTED]',
      },
    },
  });
  app.removeContentTypeParser('application/json');
  app.addContentTypeParser('application/json', { parseAs: 'string' }, (request, body, done) => {
    const rawBody = typeof body === 'string' ? body : String(body ?? '');
    request.rawBody = rawBody;
    try {
      done(null, rawBody.trim() === '' ? {} : JSON.parse(rawBody));
    } catch (error) {
      done(error as Error);
    }
  });

  const databaseUrl = options.databaseUrl ?? env.DATABASE_URL;
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
