import type { FastifyInstance } from 'fastify';
import { z } from 'zod';
import { conflict, unauthorized } from '../../lib/api-error.js';
import {
  createOpaqueToken,
  hashOpaqueToken,
  hashPassword,
  verifyPassword,
} from '../../lib/passwords-and-tokens.js';
import {
  accessTokenExpiresIn,
  createAccessToken,
  createRefreshTokenExpiry,
} from '../../lib/session-tokens.js';
import { parseBody } from '../../lib/validation.js';

const authSchema = z.object({
  email: z.string().email().transform((value) => value.trim().toLowerCase()),
  password: z.string().min(8),
});

const refreshSchema = z.object({
  refreshToken: z.string().min(1),
});

export async function registerAuthRoutes(app: FastifyInstance) {
  app.post('/v1/auth/register', async (request, reply) => {
    const input = parseBody(authSchema, request.body);
    const existingUser = await app.prisma.user.findUnique({
      where: { email: input.email },
    });
    if (existingUser) throw conflict('email_exists', 'Email already exists');

    const user = await app.prisma.user.create({
      data: {
        email: input.email,
        passwordHash: await hashPassword(input.password),
      },
    });

    const session = await createSession(app, user);
    return reply.status(201).send(session);
  });

  app.post('/v1/auth/login', async (request) => {
    const input = parseBody(authSchema, request.body);
    const user = await app.prisma.user.findUnique({
      where: { email: input.email },
    });
    if (!user || !(await verifyPassword(input.password, user.passwordHash))) {
      throw unauthorized('Invalid email or password');
    }
    return createSession(app, user);
  });

  app.post('/v1/auth/refresh', async (request) => {
    const input = parseBody(refreshSchema, request.body);
    const tokenHash = await hashOpaqueToken(input.refreshToken);
    const refreshToken = await app.prisma.refreshToken.findFirst({
      where: {
        tokenHash,
        revokedAt: null,
        expiresAt: { gt: new Date() },
      },
      include: { user: true },
    });
    if (!refreshToken) throw unauthorized('Invalid refresh token');

    await app.prisma.refreshToken.update({
      where: { id: refreshToken.id },
      data: { revokedAt: new Date() },
    });
    return createSession(app, refreshToken.user);
  });

  app.post('/v1/auth/logout', async (request, reply) => {
    const input = parseBody(refreshSchema, request.body);
    const tokenHash = await hashOpaqueToken(input.refreshToken);
    await app.prisma.refreshToken.updateMany({
      where: { tokenHash, revokedAt: null },
      data: { revokedAt: new Date() },
    });
    return reply.status(204).send();
  });
}

type SessionUser = {
  id: string;
  email: string;
  createdAt: Date;
  updatedAt: Date;
};

async function createSession(app: FastifyInstance, user: SessionUser) {
  const refreshToken = createOpaqueToken();
  await app.prisma.refreshToken.create({
    data: {
      userId: user.id,
      tokenHash: await hashOpaqueToken(refreshToken),
      expiresAt: createRefreshTokenExpiry(),
    },
  });

  return {
    user: {
      id: user.id,
      email: user.email,
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    },
    accessToken: createAccessToken({ sub: user.id, email: user.email }),
    refreshToken,
    expiresIn: accessTokenExpiresIn(),
  };
}
