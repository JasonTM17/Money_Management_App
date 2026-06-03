# Database Schema

CashFlow Manager uses SQLite for the offline-first mobile database and PostgreSQL behind the Fastify API for optional authenticated backend validation and sync foundation. Flutter must not connect directly to PostgreSQL.

## Local SQLite schema

SQLite powers the local app and remains required for offline UX.

### wallets

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| name | text | Display name |
| type | text | cash, bank, eWallet, creditCard |
| initial_balance | integer | VND integer amount |

### categories

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| name | text | Vietnamese starter label, localized in UI copy where needed |
| type | text | income, expense, transfer |
| color_hex | integer | Chart/UI color |

### transactions

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| wallet_id | text | Source wallet |
| to_wallet_id | text nullable | Target wallet for transfers |
| category_id | text | Category id |
| type | text | income, expense, transfer |
| amount | integer | Positive VND integer |
| date | text | ISO-8601 |
| note | text | User note |
| is_recurring | integer | 0/1 |

### budgets

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| category_id | text | Expense category |
| month | text | First day of month ISO |
| limit_amount | integer | VND integer amount |

### saving_goals

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| name | text | Goal name |
| target_amount | integer | VND target |
| saved_amount | integer | VND saved |
| deadline | text | ISO date |

## Local invariants

- Amounts must be positive integers.
- Transfers debit source and credit target.
- Wallet deletion should be blocked when transactions exist.
- Budget warnings trigger at 90% or more of limit.
- Forecast only applies recurring occurrences after the active report date so posted recurring ledger rows are not counted twice.
- Backup/restore validates required base lists, duplicate ids, positive amounts, and cross references before replacing local data.

## Future local sync metadata

Before enabling full bidirectional remote sync, local records need metadata that can survive offline edits and failed sync attempts.

| Field | Purpose |
|---|---|
| sync_status | clean, dirty, deleted, conflict |
| remote_revision | Last acknowledged server revision for the row |
| base_remote_revision | Server revision the local edit was based on |
| local_updated_at | Device timestamp for user-facing ordering/debugging |
| deleted_at | Tombstone timestamp for synced deletes |
| last_sync_error | Stable error key or short diagnostic for Settings sync log |

Real push/pull must not delete dirty local data when remote sync fails.

## PostgreSQL schema

PostgreSQL stores authenticated backend data behind the API. The current Prisma schema provides accounts, refresh tokens, user-owned finance tables, soft-delete fields, server revisions, sync audit events, household sharing foundations, and premium/payment foundations.

### users

| Column | Type | Notes |
|---|---|---|
| id | uuid primary key | Server user id |
| email | text unique | Normalized account email |
| password_hash | text | Password hash, never plaintext |
| created_at | timestamptz | Server timestamp |
| updated_at | timestamptz | Server timestamp |
| deleted_at | timestamptz nullable | Soft delete |

### refresh_tokens

| Column | Type | Notes |
|---|---|---|
| id | uuid primary key | Token row id |
| user_id | uuid foreign key | Owner |
| token_hash | text | Hashed refresh token |
| expires_at | timestamptz | Expiration |
| revoked_at | timestamptz nullable | Revocation timestamp |
| created_at | timestamptz | Server timestamp |

### shared finance columns

Every syncable finance table includes:

| Column | Type | Notes |
|---|---|---|
| id | uuid primary key | Client-compatible stable record id |
| user_id | uuid foreign key | Owner; never accepted from finance request bodies |
| created_at | timestamptz | Server timestamp |
| updated_at | timestamptz | Server timestamp |
| deleted_at | timestamptz nullable | Soft delete/tombstone |
| revision | bigint | Server revision for conflict detection |

### wallets

| Column | Type | Notes |
|---|---|---|
| name | text | Display name |
| type | enum WalletType | cash, bank, eWallet, creditCard |
| initial_balance | bigint | VND integer amount |

### categories

| Column | Type | Notes |
|---|---|---|
| name | text | Display name |
| type | enum FinanceRecordType | income, expense, transfer |
| color_hex | integer | Chart/UI color |

### transactions

| Column | Type | Notes |
|---|---|---|
| wallet_id | uuid foreign key | Source wallet owned by same user |
| to_wallet_id | uuid nullable foreign key | Target wallet for transfers owned by same user |
| category_id | uuid foreign key | Category owned by same user |
| transfer_group_id | uuid nullable | Groups transfer legs/operation |
| type | enum FinanceRecordType | income, expense, transfer |
| amount | bigint | Positive VND integer |
| date | timestamptz | Transaction date |
| note | text | User note, defaults empty |
| is_recurring | boolean | Recurring marker |

### budgets

| Column | Type | Notes |
|---|---|---|
| category_id | uuid foreign key | Expense category owned by same user |
| month | date | First day of month |
| limit_amount | bigint | Positive VND integer |

Constraint: unique budget per `(user_id, category_id, month)`.

### saving_goals

| Column | Type | Notes |
|---|---|---|
| name | text | Goal name |
| target_amount | bigint | Positive VND target |
| saved_amount | bigint | VND saved, zero or positive |
| deadline | date | Goal deadline |

### sync_events

| Column | Type | Notes |
|---|---|---|
| user_id | uuid foreign key | Receiver of the sync event |
| entity_type | enum SyncEntityType | wallet, category, transaction, budget, savingGoal, household, sharedBudget, entitlement |
| entity_id | uuid | Changed record id |
| operation | enum SyncOperation | create, update, delete |
| revision | bigint | Server revision after the operation |
| payload | jsonb nullable | Serialized changed row or tombstone |
| occurred_at | timestamptz | Cursor ordering timestamp |

### client_mutations

| Column | Type | Notes |
|---|---|---|
| user_id | uuid foreign key | Owner |
| client_mutation_id | text | Client idempotency key |
| created_at | timestamptz | Server timestamp |

Constraint: unique mutation per `(user_id, client_mutation_id)`.

### households and shared budgets

| Table | Purpose |
|---|---|
| households | Shared finance container with `name`, `deleted_at`, and `revision` |
| household_members | User membership with role `owner` or `member`, soft-removable via `deleted_at` |
| household_invites | Owner-created email invite with hashed one-time token, status, expiry, and accepted timestamp |
| shared_budgets | Household-scoped monthly budget with optional category id, `limit_amount`, soft delete, and revision |

Shared budget changes fan out sync events to active household members. Members can read shared budgets; current write routes are owner-only.

### entitlements and payments

| Table | Purpose |
|---|---|
| entitlements | Premium state per user, provider, subscription/order id, status, and current period end |
| payment_orders | Direct/off-store SePay order state with amount, currency, idempotency key, provider order id, checkout URL, metadata, and paid timestamp |

## PostgreSQL invariants

- Every finance row is scoped by authenticated `user_id`.
- API code derives `user_id` from auth; clients never choose another owner.
- Amounts are stored as integer VND values.
- Transaction `type` must match source/target wallet rules.
- Transfer records must keep source and target effects together.
- Budgets must reference an expense category owned by the same user.
- Saving goal `saved_amount` must be less than or equal to `target_amount` unless a future product decision changes this.
- Soft-deleted records stay available for sync tombstones.
- Server `revision` is authoritative for conflict detection.

## OpenAPI contract

`docs/openapi.yaml` is the source of truth for backend routes and remote DTO expectations. Hand-written Flutter sync models and API route validation must not drift from this contract.
