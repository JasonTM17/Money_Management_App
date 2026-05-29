# UI Flow

## Navigation

Bottom navigation has five destinations:

1. Tổng quan
2. Giao dịch
3. Ví
4. Báo cáo
5. Cài đặt

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

Shows chart and monthly report text. Export service supports CSV/text foundation; PDF UI action is present for release roadmap.

## Settings

Shows privacy lock, VND currency, backup/restore roadmap, and reset data entry.

## Stitch Prompt

See `docs/STITCH_PROMPT.md`.
