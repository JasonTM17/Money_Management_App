import 'dotenv/config';
import { z } from 'zod';

const envSchema = z
  .object({
    API_PORT: z.coerce.number().int().positive().default(3000),
    DATABASE_URL: z
      .string()
      .url()
      .default(
        'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public',
      ),
    NODE_ENV: z
      .enum(['development', 'test', 'production'])
      .default('development'),
    ACCESS_TOKEN_PRIVATE_KEY_PEM: z.string().optional(),
    ACCESS_TOKEN_PUBLIC_KEY_PEM: z.string().optional(),
    ACCESS_TOKEN_KID: z.string().default('local-development-key'),
    ACCESS_TOKEN_ISSUER: z.string().default('cashflow-manager-api'),
    ACCESS_TOKEN_AUDIENCE: z.string().default('cashflow-manager-mobile'),
    IAP_VERIFICATION_MODE: z.enum(['disabled', 'mock']).default('disabled'),
    SEPAY_ENABLED: z
      .enum(['true', 'false'])
      .default('false')
      .transform((value) => value === 'true'),
    SEPAY_WEBHOOK_SECRET: z.string().optional(),
    SEPAY_CHECKOUT_BASE_URL: z.string().url().optional(),
  })
  .superRefine((env, context) => {
    if (env.NODE_ENV !== 'production') return;
    if (!env.ACCESS_TOKEN_PRIVATE_KEY_PEM) {
      context.addIssue({
        code: 'custom',
        path: ['ACCESS_TOKEN_PRIVATE_KEY_PEM'],
        message: 'ACCESS_TOKEN_PRIVATE_KEY_PEM is required in production',
      });
    }
    if (!env.ACCESS_TOKEN_PUBLIC_KEY_PEM) {
      context.addIssue({
        code: 'custom',
        path: ['ACCESS_TOKEN_PUBLIC_KEY_PEM'],
        message: 'ACCESS_TOKEN_PUBLIC_KEY_PEM is required in production',
      });
    }
  });

export const env = envSchema.parse(process.env);
