# Technical Design

## Architecture

CashFlow Manager uses a feature-first Flutter structure with small shared core modules.

```text
lib/app                 Theme and app shell
lib/core                Finance models, money utilities, calculator, export, privacy lock
lib/data                Local SQLite store
lib/features/home       Riverpod controller and mobile screens
```

## Runtime Flow

1. `main.dart` starts `ProviderScope` and `CashFlowManagerApp`.
2. `HomeScreen` watches `financeControllerProvider`.
3. `FinanceController` loads data through `LocalFinanceStore`.
4. `LocalFinanceStore` persists data in SQLite and seeds starter wallets/categories.
5. `FinanceCalculator` derives balances, monthly totals, budget alerts, forecast, and saving suggestions.

## State Management

Riverpod `AsyncNotifierProvider` owns async loading and write commands. UI renders loading/error/data states.

## Persistence

SQLite database file: `cashflow_manager.sqlite` in app documents directory. Schema is created with `create table if not exists`. Foreign keys are enabled.

## Security and Privacy

- Offline-first by default.
- PIN is salted and SHA-256 hashed before secure storage.
- Biometric auth uses `local_auth` and native Android/iOS permissions.
- No secrets or user financial data are logged.

## Platform Notes

Android uses `FlutterFragmentActivity` for biometric compatibility. iOS includes `NSFaceIDUsageDescription`.
