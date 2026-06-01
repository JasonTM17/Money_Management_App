import type { FastifyRequest } from 'fastify';
import { unauthorized } from '../../lib/api-error.js';
import { verifyAccessToken } from '../../lib/session-tokens.js';

export function requireAuth(request: FastifyRequest) {
  const header = request.headers.authorization;
  if (!header?.startsWith('Bearer ')) throw unauthorized();
  return verifyAccessToken(header.slice('Bearer '.length));
}
