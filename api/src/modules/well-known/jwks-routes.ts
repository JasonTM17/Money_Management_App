import type { FastifyInstance } from 'fastify';
import { getPublicJwks } from '../../lib/session-tokens.js';

export async function registerJwksRoutes(app: FastifyInstance) {
  app.get('/.well-known/jwks.json', async () => getPublicJwks());
}
