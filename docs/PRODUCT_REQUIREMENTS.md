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
- Reports: month report, income/expense chart, category pie, top category, CSV preview, and PDF sharing.
- Forecast: future recurring transaction projection and upcoming bill reminders.
- Saving goals: target, saved, deadline, progress, create/edit/delete flow, suggested monthly saving logic.
- Settings: VND, backup/restore, export/import data, privacy lock, reset entry.

## Should Have

- More edit screens and validation-state coverage.
- Dark/light mode setting persistence.
- More report filters and line/yearly chart variants.

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
