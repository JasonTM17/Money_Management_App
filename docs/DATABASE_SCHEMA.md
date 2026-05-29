# Database Schema

SQLite powers the MVP local database.

## wallets

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| name | text | Display name |
| type | text | cash, bank, eWallet, creditCard |
| initial_balance | integer | VND integer amount |

## categories

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| name | text | Vietnamese label |
| type | text | income, expense, transfer |
| color_hex | integer | Chart/UI color |

## transactions

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

## budgets

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| category_id | text | Expense category |
| month | text | First day of month ISO |
| limit_amount | integer | VND integer amount |

## saving_goals

| Column | Type | Notes |
|---|---|---|
| id | text primary key | Stable local id |
| name | text | Goal name |
| target_amount | integer | VND target |
| saved_amount | integer | VND saved |
| deadline | text | ISO date |

## Invariants

- Amounts must be positive integers.
- Transfers debit source and credit target.
- Wallet deletion should be blocked when transactions exist.
- Budget warnings trigger at 90% or more of limit.
