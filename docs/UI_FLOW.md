# UI Flow

## Navigation

Bottom navigation has six destinations:

1. Tổng quan
2. Giao dịch
3. Ví
4. Ngân sách
5. Báo cáo
6. Cài đặt

A prominent floating action button opens the quick add transaction sheet.

## Screens

## Onboarding and Lock

MVP includes privacy lock service and native permission setup. Full onboarding wizard is roadmap polish; current app opens into dashboard with local seeded data.

## Dashboard

- Tổng số dư hiện tại
- Thu tháng này
- Chi tháng này
- Net cashflow
- Thu/chi chart
- Giao dịch gần đây
- Budget warning card

## Add Transaction

Bottom sheet flow:

1. Choose Chi/Thu.
2. Enter amount.
3. Enter note.
4. Save into local SQLite store.
5. Dashboard reloads from store.

## Wallets and Goals

Shows wallet balances and saving goal progress.

## Reports

Shows income/expense chart, category pie, top spending categories, forecast cards, monthly report text, CSV preview, and PDF share action.

## Settings

Shows privacy lock, VND currency, backup/restore actions, and reset data entry.

## Stitch Prompt

See `docs/STITCH_PROMPT.md`.
