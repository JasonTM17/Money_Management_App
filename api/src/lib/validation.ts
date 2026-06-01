import { z } from 'zod';
import { badRequest } from './api-error.js';

export function parseBody<T>(schema: z.ZodType<T>, body: unknown): T {
  const parsed = schema.safeParse(body);
  if (!parsed.success) {
    throw badRequest('validation_failed', 'Request validation failed', {
      issues: parsed.error.flatten(),
    });
  }
  return parsed.data;
}
