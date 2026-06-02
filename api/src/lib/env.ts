import 'dotenv/config';
import { z } from 'zod';

const rawSchema = z.object({
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
  JWT_PRIVATE_KEY: z.string().optional(),
  JWT_PUBLIC_KEY: z.string().optional(),
  ACCESS_TOKEN_PRIVATE_KEY_PEM: z.string().optional(),
  ACCESS_TOKEN_PUBLIC_KEY_PEM: z.string().optional(),
  ACCESS_TOKEN_KID: z.string().default('local-development-key'),
  ACCESS_TOKEN_ISSUER: z.string().default('cashflow-manager-api'),
  ACCESS_TOKEN_AUDIENCE: z.string().default('cashflow-manager-mobile'),
  N8N_CHATBOT_WEBHOOK_URL: z.string().url().optional(),
  N8N_CHATBOT_WEBHOOK_SECRET: z.string().optional(),
  N8N_CHATBOT_ALLOWED_HOSTS: z.string().optional(),
  IAP_VERIFICATION_MODE: z.enum(['disabled', 'mock']).default('disabled'),
  SEPAY_ENABLED: z
    .enum(['true', 'false'])
    .default('false')
    .transform((value) => value === 'true'),
  SEPAY_WEBHOOK_SECRET: z.string().optional(),
  SEPAY_CHECKOUT_BASE_URL: z.string().url().optional(),
});

type RawEnv = z.infer<typeof rawSchema>;

const envSchema = rawSchema
  .transform((env) => {
    const resolved: RawEnv & {
      jwtPrivateKey: string;
      jwtPublicKey: string;
    } = {
      ...env,
      jwtPrivateKey: env.JWT_PRIVATE_KEY ?? env.ACCESS_TOKEN_PRIVATE_KEY_PEM ?? '',
      jwtPublicKey: env.JWT_PUBLIC_KEY ?? env.ACCESS_TOKEN_PUBLIC_KEY_PEM ?? '',
    };
    return resolved;
  })
  .superRefine((env, context) => {
    if (env.NODE_ENV !== 'production') return;
    if (!env.jwtPrivateKey) {
      context.addIssue({
        code: 'custom',
        path: ['JWT_PRIVATE_KEY'],
        message: 'JWT_PRIVATE_KEY (or ACCESS_TOKEN_PRIVATE_KEY_PEM) is required in production',
      });
    }
    if (!env.jwtPublicKey) {
      context.addIssue({
        code: 'custom',
        path: ['JWT_PUBLIC_KEY'],
        message: 'JWT_PUBLIC_KEY (or ACCESS_TOKEN_PUBLIC_KEY_PEM) is required in production',
      });
    }
    if (env.N8N_CHATBOT_WEBHOOK_URL) {
      const parsed = new URL(env.N8N_CHATBOT_WEBHOOK_URL);
      if (parsed.protocol !== 'https:') {
        context.addIssue({
          code: 'custom',
          path: ['N8N_CHATBOT_WEBHOOK_URL'],
          message: 'N8N_CHATBOT_WEBHOOK_URL must use https in production',
        });
      }
      if (!env.N8N_CHATBOT_WEBHOOK_SECRET) {
        context.addIssue({ code: 'custom', path: ['N8N_CHATBOT_WEBHOOK_SECRET'], message: 'N8N_CHATBOT_WEBHOOK_SECRET is required when AI webhook is configured' });
      }
    }
  });

export const env = envSchema.parse(process.env);
