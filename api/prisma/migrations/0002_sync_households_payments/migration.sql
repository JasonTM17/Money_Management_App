CREATE TYPE "SyncEntityType" AS ENUM ('wallet', 'category', 'transaction', 'budget', 'savingGoal', 'household', 'sharedBudget', 'entitlement');
CREATE TYPE "SyncOperation" AS ENUM ('create', 'update', 'delete');
CREATE TYPE "HouseholdRole" AS ENUM ('owner', 'member');
CREATE TYPE "HouseholdInviteStatus" AS ENUM ('pending', 'accepted', 'revoked', 'expired');
CREATE TYPE "EntitlementProvider" AS ENUM ('apple', 'google', 'sepay', 'manual');
CREATE TYPE "EntitlementStatus" AS ENUM ('pending', 'active', 'expired', 'revoked');
CREATE TYPE "PaymentOrderStatus" AS ENUM ('pending', 'paid', 'expired', 'cancelled');

CREATE TABLE "sync_events" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "entity_type" "SyncEntityType" NOT NULL,
  "entity_id" UUID NOT NULL,
  "operation" "SyncOperation" NOT NULL,
  "revision" BIGINT NOT NULL,
  "payload" JSONB,
  "occurred_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "sync_events_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "client_mutations" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "client_mutation_id" TEXT NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "client_mutations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "households" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "name" TEXT NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  "deleted_at" TIMESTAMPTZ(6),
  "revision" BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT "households_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "household_members" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "household_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "role" "HouseholdRole" NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "deleted_at" TIMESTAMPTZ(6),
  CONSTRAINT "household_members_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "household_invites" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "household_id" UUID NOT NULL,
  "inviter_id" UUID NOT NULL,
  "invitee_email" TEXT NOT NULL,
  "invitee_id" UUID,
  "status" "HouseholdInviteStatus" NOT NULL DEFAULT 'pending',
  "token_hash" TEXT NOT NULL,
  "expires_at" TIMESTAMPTZ(6) NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "accepted_at" TIMESTAMPTZ(6),
  CONSTRAINT "household_invites_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "shared_budgets" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "household_id" UUID NOT NULL,
  "category_id" UUID,
  "name" TEXT NOT NULL,
  "month" DATE NOT NULL,
  "limit_amount" BIGINT NOT NULL,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  "deleted_at" TIMESTAMPTZ(6),
  "revision" BIGINT NOT NULL DEFAULT 1,
  CONSTRAINT "shared_budgets_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "entitlements" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "plan" TEXT NOT NULL,
  "provider" "EntitlementProvider" NOT NULL,
  "provider_subscription_id" TEXT,
  "status" "EntitlementStatus" NOT NULL,
  "current_period_end" TIMESTAMPTZ(6),
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  CONSTRAINT "entitlements_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "payment_orders" (
  "id" UUID NOT NULL DEFAULT gen_random_uuid(),
  "user_id" UUID NOT NULL,
  "provider" "EntitlementProvider" NOT NULL,
  "amount" BIGINT NOT NULL,
  "currency" TEXT NOT NULL,
  "status" "PaymentOrderStatus" NOT NULL DEFAULT 'pending',
  "provider_order_id" TEXT,
  "idempotency_key" TEXT NOT NULL,
  "checkout_url" TEXT,
  "metadata" JSONB,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMPTZ(6) NOT NULL,
  "paid_at" TIMESTAMPTZ(6),
  CONSTRAINT "payment_orders_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "sync_events_user_id_occurred_at_idx" ON "sync_events"("user_id", "occurred_at");
CREATE INDEX "sync_events_user_id_entity_type_entity_id_idx" ON "sync_events"("user_id", "entity_type", "entity_id");
CREATE UNIQUE INDEX "client_mutations_user_id_client_mutation_id_key" ON "client_mutations"("user_id", "client_mutation_id");
CREATE UNIQUE INDEX "household_members_household_id_user_id_key" ON "household_members"("household_id", "user_id");
CREATE INDEX "household_members_user_id_deleted_at_idx" ON "household_members"("user_id", "deleted_at");
CREATE INDEX "household_invites_household_id_status_idx" ON "household_invites"("household_id", "status");
CREATE INDEX "household_invites_invitee_email_status_idx" ON "household_invites"("invitee_email", "status");
CREATE INDEX "shared_budgets_household_id_deleted_at_idx" ON "shared_budgets"("household_id", "deleted_at");
CREATE INDEX "entitlements_user_id_status_idx" ON "entitlements"("user_id", "status");
CREATE UNIQUE INDEX "entitlements_provider_provider_subscription_id_key" ON "entitlements"("provider", "provider_subscription_id");
CREATE UNIQUE INDEX "payment_orders_user_id_idempotency_key_key" ON "payment_orders"("user_id", "idempotency_key");
CREATE INDEX "payment_orders_provider_provider_order_id_idx" ON "payment_orders"("provider", "provider_order_id");

ALTER TABLE "sync_events" ADD CONSTRAINT "sync_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "client_mutations" ADD CONSTRAINT "client_mutations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_household_id_fkey" FOREIGN KEY ("household_id") REFERENCES "households"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "household_members" ADD CONSTRAINT "household_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "household_invites" ADD CONSTRAINT "household_invites_household_id_fkey" FOREIGN KEY ("household_id") REFERENCES "households"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "household_invites" ADD CONSTRAINT "household_invites_inviter_id_fkey" FOREIGN KEY ("inviter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "household_invites" ADD CONSTRAINT "household_invites_invitee_id_fkey" FOREIGN KEY ("invitee_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "shared_budgets" ADD CONSTRAINT "shared_budgets_household_id_fkey" FOREIGN KEY ("household_id") REFERENCES "households"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "entitlements" ADD CONSTRAINT "entitlements_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "payment_orders" ADD CONSTRAINT "payment_orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
