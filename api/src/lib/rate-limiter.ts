import type { FastifyRequest } from 'fastify';
import { rateLimited } from './api-error.js';

type RateLimitOptions = {
  windowMs: number;
  maxAttempts: number;
  message?: string;
};

type RateLimitEntry = {
  count: number;
  resetAt: number;
};

export class InMemoryRateLimiter {
  private readonly attempts = new Map<string, RateLimitEntry>();

  constructor(private readonly options: RateLimitOptions) {}

  check(key: string) {
    const now = Date.now();
    this.prune(now);
    const existing = this.attempts.get(key);
    if (!existing || existing.resetAt <= now) {
      this.attempts.set(key, {
        count: 1,
        resetAt: now + this.options.windowMs,
      });
      return;
    }
    if (existing.count >= this.options.maxAttempts) {
      throw rateLimited(this.options.message);
    }
    existing.count += 1;
  }

  private prune(now: number) {
    if (this.attempts.size < 1000) return;
    for (const [key, value] of this.attempts.entries()) {
      if (value.resetAt <= now) this.attempts.delete(key);
    }
  }
}

export function requestIp(request: FastifyRequest) {
  return request.ip || request.socket.remoteAddress || 'unknown';
}

export function normalizeRateLimitPart(value: string | undefined) {
  return value?.trim().toLowerCase() || 'unknown';
}

export function rateLimitKey(
  request: FastifyRequest,
  scope: string,
  identifier?: string,
) {
  return `${scope}:${requestIp(request)}:${normalizeRateLimitPart(identifier)}`;
}
