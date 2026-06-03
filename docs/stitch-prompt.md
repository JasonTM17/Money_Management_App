# Stitch Prompt And Evidence

This file preserves the original Stitch design-input prompt and the later verified Stitch MCP evidence. Treat the prompt as historical context, not the current implemented UI contract.

## Verified Stitch Evidence

- Stitch project: `projects/10529407878013129791`
- Design system: `assets/6d53f97cfc3348c49b4ce89f7d182ae5`
- Design system name: `Premium Fiscal Flow`
- Font: Be Vietnam Pro
- Dark base: `#051424`
- Primary finance accent: `#16A34A` baseline and `#62DF7D` dark-mode tone
- Semantic colors: income blue, expense red, warning amber, neutral slate
- Layout rules: 8px base spacing, 20px mobile margins, 12px gutters, 16px card inset, 48px minimum tap targets
- Current implemented navigation contract: five bottom tabs plus app-bar Add Transaction and Settings actions, with no floating action button overlay.

## Historical Prompt

The original prompt below mentions six bottom tabs and a floating action button. That is no longer the implemented contract because the approved Stitch+ pass keeps Settings in the app bar and removes the FAB to avoid crowding and content overlap.

```text
Design a modern mobile personal finance app named CashFlow Manager for Android and iOS. Vietnamese-first UI. Style: clean, premium but friendly, financial dashboard, green primary (#16A34A), deep slate backgrounds, amber warning, red expense, blue income. Must support light and dark mode visual language. Generate a complete mobile app design system and key screens: onboarding, PIN/biometric lock, dashboard with balance/month income/month expense/net cashflow/charts/recent transactions/budget alerts, quick add transaction form, transaction list with filters/search/edit/delete, wallet/account list and transfer flow, budgets by month/category, reports with pie/line/bar charts and export CSV/PDF actions, cashflow forecast with recurring bills and warnings, saving goals, settings with theme/currency/backup/privacy/reset. Navigation: bottom tabs Dashboard, Transactions, Wallets, Budgets, Reports, Settings; prominent floating add transaction button. Components: balance cards, stat cards, transaction row, wallet card, category chip, chart card, budget progress, empty states, form fields, date picker, segmented controls, export bottom sheet. Typography: Inter-like, high readability. Include Vietnamese labels like Tổng số dư, Thu tháng này, Chi tháng này, Thêm giao dịch, Ngân sách, Báo cáo, Dòng tiền, Mục tiêu tiết kiệm. Avoid clutter; large tap targets; accessible contrast.
```
