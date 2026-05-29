# Test Plan

## Automated Commands

```bash
flutter analyze
flutter test
flutter build apk --debug
```

## Unit Tests

| Area | Coverage |
|---|---|
| Money parsing | Empty, zero, formatted VND |
| Wallet balance | Income, expense, transfer |
| Budget warning | 90% threshold |
| Saving goals | Required monthly saving |
| Export | Empty CSV, monthly text report, PDF payload |
| Forecast | Future recurring occurrences only |

## Widget Tests

- Privacy lock first-run PIN and existing PIN unlock flows.
- Dashboard shell renders app title, FAB, and total balance section.
- Budget create/delete and saving goal create/delete flows, with edit flows noted for follow-up coverage.
- Wallet transfer updates source and target balances.
- Transaction search/delete and transfer-row behavior.
- Report insight, forecast, CSV/PDF preview, and backup/restore entry flows.
- Test overrides Riverpod store to avoid native plugin dependency.

## Manual QA Checklist

- [ ] App launches on Android emulator/device.
- [ ] Dashboard shows seeded balances and transactions.
- [ ] Add expense with invalid amount shows validation error.
- [ ] Add expense with valid amount closes sheet and refreshes list.
- [ ] Bottom navigation switches between tabs.
- [ ] Reports chart renders without crash.
- [ ] Settings screen shows privacy lock and VND entries.

## Edge Cases

- Negative/zero amount rejected.
- Wallet transfer logic keeps total balance constant.
- Budget near limit triggers alert.
- Month without transactions returns zero income/expense.
- Export with empty data still has CSV headers.
- VND formatting has zero decimals.
