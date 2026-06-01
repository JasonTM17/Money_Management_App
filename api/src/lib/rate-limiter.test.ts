import { describe, expect, it } from 'vitest';
import { ApiError } from './api-error.js';
import { InMemoryRateLimiter } from './rate-limiter.js';

describe('in-memory rate limiter', () => {
  it('throws a stable API error after the configured limit', () => {
    const limiter = new InMemoryRateLimiter({
      windowMs: 60_000,
      maxAttempts: 2,
      message: 'Too many authentication attempts',
    });

    limiter.check('auth:127.0.0.1:demo@example.com');
    limiter.check('auth:127.0.0.1:demo@example.com');

    expect(() => limiter.check('auth:127.0.0.1:demo@example.com')).toThrowError(
      ApiError,
    );
  });
});
