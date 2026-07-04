# UI Flow

## Navigation

Bottom navigation has five primary destinations:

1. Tổng quan
2. Giao dịch
3. Ví
4. Ngân sách
5. Báo cáo

The app bar keeps two global actions visible without covering scroll content:

- Add transaction opens the quick add transaction sheet.
- Settings opens the settings route for theme, language, backup, privacy, and reset controls.

## Onboarding and Lock

First-run privacy setup prompts for a local PIN before showing financial data. Existing PIN users see the unlock screen first, can use biometric unlock only after opting in from Settings, and are relocked when the app leaves foreground.

Sensitive flows such as data reset and backup restore require re-authentication when a privacy PIN exists. This keeps the app offline-first while still protecting destructive actions on shared or unattended devices.

## Dashboard

- Tổng số dư hiện tại
- Net cashflow pill inside the balance hero
- Compact income/expense mini metrics inside the balance hero
- Thu tháng này
- Chi tháng này
- Dòng tiền ròng
- Thu/chi chart
- Giao dịch gần đây
- Budget warning card

## Add Transaction

Bottom sheet flow:

1. Choose Chi/Thu.
2. Choose wallet and category.
3. Enter amount, note, date, and recurring flag.
4. Save into local SQLite store.
5. Dashboard, transactions, budgets, wallets, and reports reload from store.

## Transactions

The transactions tab supports search, wallet/category/month filters, compact
result count, quick filter reset, edit for income/expense rows, delete
confirmation, and read-only display for wallet transfers.

## Wallets and Goals

Wallets start with a portfolio summary showing total balance and wallet count,
then show current balances by wallet type. Users can transfer money between
different wallets with same-wallet validation. Saving goals show progress,
remaining amount, deadline, and suggested monthly saving.

## Budgets

Budgets are managed per expense category and selected month. Budget cards show progress, spend, remaining amount, and warning state near the configured threshold.

## Reports

Reports show selected-month income/expense chart, category pie, top spending categories, forecast cards, monthly report text, CSV preview, PDF sharing, and month navigation.

## Settings

Settings is an app-bar route, not a bottom navigation tab. It includes theme mode, language, privacy lock state, biometric opt-in, optional account/sync status, backup/restore actions, data reset, and app safety notes. Reset and restore require explicit confirmation plus re-authentication before local data is replaced.

The account/sync panel is optional and isolated from local finance tracking. Signed-out users can open a login/register sheet. Signed-in users can refresh entitlement state or log out; logout clears local sync tokens even when the server is unavailable. Local wallet, transaction, budget, and report flows continue to work without an account or network.

## Demo Media

README screenshots and GIF are generated from deterministic fake financial data through `scripts/capture_demo_media_test.dart`. Do not capture real user finance data, secrets, terminal output, local paths, or visible n8n credentials for repository media.

Latest refreshed media set was captured after the July 2026 professional mobile
UI pass and includes dashboard, transactions, wallets, budgets, reports, and
privacy/settings screens.

## Stitch Prompt

See `docs/stitch-prompt.md` for the historical prompt and verified Stitch design-system evidence.
