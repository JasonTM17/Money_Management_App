import 'finance_models.dart';

part 'sync_auth_models.dart';
part 'sync_change_models.dart';

class RemoteSyncBootstrap {
  const RemoteSyncBootstrap({
    required this.cursor,
    required this.wallets,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.savingGoals,
  });

  final String cursor;
  final List<WalletAccount> wallets;
  final List<FinanceCategory> categories;
  final List<FinanceTransaction> transactions;
  final List<Budget> budgets;
  final List<SavingGoal> savingGoals;

  factory RemoteSyncBootstrap.fromJson(Map<String, Object?> json) {
    return RemoteSyncBootstrap(
      cursor: _string(json, 'cursor'),
      wallets: _list(json, 'wallets', _walletFromJson),
      categories: _list(json, 'categories', _categoryFromJson),
      transactions: _list(json, 'transactions', _transactionFromJson),
      budgets: _list(json, 'budgets', _budgetFromJson),
      savingGoals: _list(json, 'savingGoals', _savingGoalFromJson),
    );
  }
}

WalletAccount _walletFromJson(Map<String, Object?> json) => WalletAccount(
  id: _string(json, 'id'),
  name: _string(json, 'name'),
  type: WalletType.values.byName(_string(json, 'type')),
  initialBalance: _int(json, 'initialBalance'),
);

FinanceCategory _categoryFromJson(Map<String, Object?> json) => FinanceCategory(
  id: _string(json, 'id'),
  name: _string(json, 'name'),
  type: TransactionType.values.byName(_string(json, 'type')),
  colorHex: _int(json, 'colorHex'),
);

FinanceTransaction _transactionFromJson(Map<String, Object?> json) {
  final toWalletId = json['toWalletId'];
  return FinanceTransaction(
    id: _string(json, 'id'),
    walletId: _string(json, 'walletId'),
    toWalletId: toWalletId is String ? toWalletId : null,
    categoryId: _string(json, 'categoryId'),
    type: TransactionType.values.byName(_string(json, 'type')),
    amount: _int(json, 'amount'),
    date: DateTime.parse(_string(json, 'date')),
    note: _string(json, 'note'),
    isRecurring: _bool(json, 'isRecurring'),
  );
}

Budget _budgetFromJson(Map<String, Object?> json) => Budget(
  id: _string(json, 'id'),
  categoryId: _string(json, 'categoryId'),
  month: DateTime.parse(_string(json, 'month')),
  limitAmount: _int(json, 'limitAmount'),
);

SavingGoal _savingGoalFromJson(Map<String, Object?> json) => SavingGoal(
  id: _string(json, 'id'),
  name: _string(json, 'name'),
  targetAmount: _int(json, 'targetAmount'),
  savedAmount: _int(json, 'savedAmount'),
  deadline: DateTime.parse(_string(json, 'deadline')),
);

List<T> _list<T>(
  Map<String, Object?> json,
  String key,
  T Function(Map<String, Object?>) decode,
) {
  final value = json[key];
  if (value is! List) throw FormatException('invalidSyncPayload');
  return value.map((item) {
    if (item is! Map<String, Object?>) {
      throw const FormatException('invalidSyncPayload');
    }
    return decode(item);
  }).toList();
}

List<Map<String, Object?>> _mapList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw const FormatException('invalidSyncPayload');
  return value.map((item) {
    if (item is! Map<String, Object?>) {
      throw const FormatException('invalidSyncPayload');
    }
    return item;
  }).toList();
}

List<String> _stringList(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! List) throw const FormatException('invalidSyncPayload');
  return value.map((item) {
    if (item is! String) throw const FormatException('invalidSyncPayload');
    return item;
  }).toList();
}

Map<String, Object?> _object(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! Map<String, Object?>) {
    throw const FormatException('invalidSyncPayload');
  }
  return value;
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is! String) throw FormatException('invalidSyncPayload');
  return value;
}

int _int(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is int) return value;
  throw const FormatException('invalidSyncPayload');
}

bool _bool(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is bool) return value;
  throw FormatException('invalidSyncPayload');
}
