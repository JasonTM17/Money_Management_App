import type { FastifyInstance } from 'fastify';
import { serviceUnavailable } from '../../lib/api-error.js';

export async function registerHealthRoutes(app: FastifyInstance) {
  app.get('/healthz', async () => ({ status: 'ok' }));

  app.get('/readyz', async () => {
    try {
      await app.prisma.$queryRaw`SELECT 1 FROM "users" LIMIT 1`;
      return { status: 'ok' };
    } catch {
      throw serviceUnavailable('database_not_ready', 'Database is not migrated or unavailable');
    }
  });
}
