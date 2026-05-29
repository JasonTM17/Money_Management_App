# Product Requirements

## Overview

CashFlow Manager helps Vietnamese users track personal income, expenses, wallets, budgets, reports, forecasts, and saving goals from an offline-first mobile app.

## Personas

| Persona | Need |
|---|---|
| Nhân viên văn phòng | Track salary, daily spending, monthly budget |
| Freelancer | Separate irregular income and cashflow forecast |
| Gia đình nhỏ | See wallet balances, bills, category spending |
| Sinh viên | Simple budget and spending alerts |

## Must Have

- Onboarding and privacy lock path with PIN/biometric support.
- Dashboard: total balance, month income, month expense, net cashflow, chart, recent transactions, budget alerts.
- Transactions: add income/expense, wallet, category, amount, date, note, recurring flag in model.
- Wallets: cash, bank, e-wallet, credit-card-ready model, transfer logic.
- Budgets: monthly/category budget and warning at 90%+.
- Reports: month report, charts, CSV/text export service.
- Forecast: recurring transaction projection.
- Saving goals: target, saved, deadline, suggested monthly saving.
- Settings: theme-ready, VND, backup/export/privacy/reset placeholders.

## Should Have

- Better edit/delete screens.
- Full PDF generation UI.
- Import/restore file picker.
- More chart variants and filters.

## Could Have

- Supabase/Firebase sync.
- Receipt images/OCR.
- Shared household budgets.
- Bank integration.

## Out of Scope for MVP

- Live bank scraping.
- Multi-user sync.
- Paid subscriptions.
- OCR receipt scanning.

## Acceptance Criteria

- App runs as a Flutter Android/iOS project.
- All core finance calculations use integer VND amounts.
- Analyze and tests pass.
- Android debug build succeeds.
- Required docs and CI workflow exist.
