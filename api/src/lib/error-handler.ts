import prismaClient from '@prisma/client';
import type { FastifyError, FastifyReply, FastifyRequest } from 'fastify';

const { Prisma } = prismaClient;
import { ZodError } from 'zod';
import { ApiError } from './api-error.js';

export function handleApiError(
  error: FastifyError | Error,
  _request: FastifyRequest,
  reply: FastifyReply,
) {
  if (error instanceof ApiError) {
    return reply.status(error.statusCode).send({
      code: error.code,
      message: error.message,
      details: error.details,
    });
  }

  if (error instanceof ZodError) {
    return reply.status(400).send({
      code: 'validation_failed',
      message: 'Request validation failed',
      details: { issues: error.flatten() },
    });
  }

  if (error instanceof Prisma.PrismaClientKnownRequestError) {
    if (error.code === 'P2002') {
      return reply.status(409).send({
        code: 'unique_constraint_failed',
        message: 'Record already exists',
      });
    }
    if (error.code === 'P2003') {
      return reply.status(400).send({
        code: 'invalid_reference',
        message: 'Referenced record does not exist',
      });
    }
  }

  return reply.status(500).send({
    code: 'internal_error',
    message: 'Internal server error',
  });
}
