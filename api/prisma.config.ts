import 'dotenv/config';
import { defineConfig } from 'prisma/config';

const databaseUrl =
  process.env.DATABASE_URL ??
  'postgresql://cashflow_app:change-me-local-only@localhost:5432/cashflow_manager?schema=public';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
    seed: process.env.PRISMA_SEED_COMMAND ?? 'tsx prisma/seed.ts',
  },
  datasource: {
    url: databaseUrl,
  },
});
