ALTER TABLE "wallets"
  ADD CONSTRAINT "wallets_initial_balance_nonnegative" CHECK ("initial_balance" >= 0),
  ADD CONSTRAINT "wallets_revision_positive" CHECK ("revision" >= 1);

ALTER TABLE "categories"
  ADD CONSTRAINT "categories_revision_positive" CHECK ("revision" >= 1);

ALTER TABLE "transactions"
  ADD CONSTRAINT "transactions_amount_positive" CHECK ("amount" > 0),
  ADD CONSTRAINT "transactions_revision_positive" CHECK ("revision" >= 1),
  ADD CONSTRAINT "transactions_transfer_shape" CHECK (
    (
      "type" = 'transfer'
      AND "to_wallet_id" IS NOT NULL
      AND "to_wallet_id" <> "wallet_id"
    )
    OR
    (
      "type" <> 'transfer'
      AND "to_wallet_id" IS NULL
    )
  );

ALTER TABLE "budgets"
  ADD CONSTRAINT "budgets_limit_amount_positive" CHECK ("limit_amount" > 0),
  ADD CONSTRAINT "budgets_month_first_day" CHECK (EXTRACT(DAY FROM "month") = 1),
  ADD CONSTRAINT "budgets_revision_positive" CHECK ("revision" >= 1);

ALTER TABLE "saving_goals"
  ADD CONSTRAINT "saving_goals_amounts_valid" CHECK (
    "target_amount" > 0
    AND "saved_amount" >= 0
    AND "saved_amount" <= "target_amount"
  ),
  ADD CONSTRAINT "saving_goals_revision_positive" CHECK ("revision" >= 1);

ALTER TABLE "households"
  ADD CONSTRAINT "households_revision_positive" CHECK ("revision" >= 1);

ALTER TABLE "shared_budgets"
  ADD CONSTRAINT "shared_budgets_limit_amount_positive" CHECK ("limit_amount" > 0),
  ADD CONSTRAINT "shared_budgets_month_first_day" CHECK (EXTRACT(DAY FROM "month") = 1),
  ADD CONSTRAINT "shared_budgets_revision_positive" CHECK ("revision" >= 1);

ALTER TABLE "payment_orders"
  ADD CONSTRAINT "payment_orders_amount_positive" CHECK ("amount" > 0);