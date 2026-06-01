import 'dart:convert';

import 'finance_models.dart';

class FinanceBackupData {
  const FinanceBackupData({
    required this.wallets,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.goals,
  });

  final List<WalletAccount> wallets;
  final List<FinanceCategory> categories;
  final List<FinanceTransaction> transactions;
  final List<Budget> budgets;
  final List<SavingGoal> goals;
}

class FinanceBackupPreview {
  const FinanceBackupPreview({
    required this.walletCount,
    required this.transactionCount,
    required this.budgetCount,
    required this.goalCount,
    this.exportedAt,
  });

  final int walletCount;
  final int transactionCount;
  final int budgetCount;
  final int goalCount;
  final DateTime? exportedAt;
}

class FinanceBackupService {
  const FinanceBackupService();

  String encode({
    required List<WalletAccount> wallets,
    required List<FinanceCategory> categories,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
    required List<SavingGoal> goals,
  }) {
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'cashflow_manager',
      'schemaVersion': 1,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'wallets': wallets.map(_walletToJson).toList(),
      'categories': categories.map(_categoryToJson).toList(),
      'transactions': transactions.map(_transactionToJson).toList(),
      'budgets': budgets.map(_budgetToJson).toList(),
      'goals': goals.map(_goalToJson).toList(),
    });
  }

  FinanceBackupPreview preview(String input) {
    final root = _root(input);
    return FinanceBackupPreview(
      walletCount: _list(root, 'wallets').length,
      transactionCount: _list(root, 'transactions').length,
      budgetCount: _list(root, 'budgets').length,
      goalCount: _list(root, 'goals').length,
      exportedAt: _optionalDateTime(root['exportedAt']),
    );
  }

  FinanceBackupData decode(String input) {
    final root = _root(input);
    final wallets = _list(root, 'wallets').map(_walletFromJson).toList();
    final categories = _list(
      root,
      'categories',
    ).map(_categoryFromJson).toList();
    final transactions = _list(
      root,
      'transactions',
    ).map(_transactionFromJson).toList();
    final budgets = _list(root, 'budgets').map(_budgetFromJson).toList();
    final goals = _list(root, 'goals').map(_goalFromJson).toList();
    if (wallets.isEmpty) {
      throw const FormatException('backupWalletRequired');
    }
    if (categories.isEmpty) {
      throw const FormatException('backupCategoryRequired');
    }
    _validateIds(wallets.map((item) => item.id));
    _validateIds(categories.map((item) => item.id));
    _validateIds(transactions.map((item) => item.id));
    _validateIds(budgets.map((item) => item.id));
    _validateIds(goals.map((item) => item.id));
    _validateReferences(
      wallets: wallets,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
    );
    return FinanceBackupData(
      wallets: wallets,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
    );
  }

  Map<String, Object?> _walletToJson(WalletAccount item) => {
    'id': item.id,
    'name': item.name,
    'type': item.type.name,
    'initialBalance': item.initialBalance,
  };

  Map<String, Object?> _categoryToJson(FinanceCategory item) => {
    'id': item.id,
    'name': item.name,
    'type': item.type.name,
    'colorHex': item.colorHex,
  };

  Map<String, Object?> _transactionToJson(FinanceTransaction item) => {
    'id': item.id,
    'walletId': item.walletId,
    'toWalletId': item.toWalletId,
    'categoryId': item.categoryId,
    'type': item.type.name,
    'amount': item.amount,
    'date': item.date.toIso8601String(),
    'note': item.note,
    'isRecurring': item.isRecurring,
  };

  Map<String, Object?> _budgetToJson(Budget item) => {
    'id': item.id,
    'categoryId': item.categoryId,
    'month': item.month.toIso8601String(),
    'limitAmount': item.limitAmount,
  };

  Map<String, Object?> _goalToJson(SavingGoal item) => {
    'id': item.id,
    'name': item.name,
    'targetAmount': item.targetAmount,
    'savedAmount': item.savedAmount,
    'deadline': item.deadline.toIso8601String(),
  };

  WalletAccount _walletFromJson(Object? value) {
    final item = _map(value);
    return WalletAccount(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      type: _walletType(item, 'type'),
      initialBalance: _nonNegativeInt(item, 'initialBalance'),
    );
  }

  FinanceCategory _categoryFromJson(Object? value) {
    final item = _map(value);
    return FinanceCategory(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      type: _transactionType(item, 'type'),
      colorHex: _nonNegativeInt(item, 'colorHex'),
    );
  }

  FinanceTransaction _transactionFromJson(Object? value) {
    final item = _map(value);
    return FinanceTransaction(
      id: _string(item, 'id'),
      walletId: _string(item, 'walletId'),
      toWalletId: item['toWalletId'] == null
          ? null
          : _string(item, 'toWalletId'),
      categoryId: _string(item, 'categoryId'),
      type: _transactionType(item, 'type'),
      amount: _positiveInt(item, 'amount'),
      date: _dateTime(item, 'date'),
      note: _string(item, 'note'),
      isRecurring: _bool(item, 'isRecurring'),
    );
  }

  Budget _budgetFromJson(Object? value) {
    final item = _map(value);
    return Budget(
      id: _string(item, 'id'),
      categoryId: _string(item, 'categoryId'),
      month: _dateTime(item, 'month'),
      limitAmount: _positiveInt(item, 'limitAmount'),
    );
  }

  SavingGoal _goalFromJson(Object? value) {
    final item = _map(value);
    final targetAmount = _positiveInt(item, 'targetAmount');
    final savedAmount = _nonNegativeInt(item, 'savedAmount');
    if (savedAmount > targetAmount) {
      throw const FormatException('goalSavedExceedsTarget');
    }
    return SavingGoal(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: _dateTime(item, 'deadline'),
    );
  }

  Map<String, Object?> _root(String input) {
    final root = jsonDecode(input);
    if (root is! Map<String, Object?>) {
      throw const FormatException('backupInvalidFile');
    }
    if (root['app'] != 'cashflow_manager' || root['schemaVersion'] != 1) {
      throw const FormatException('backupUnsupportedVersion');
    }
    _optionalDateTime(root['exportedAt']);
    return root;
  }

  DateTime? _optionalDateTime(Object? value) {
    if (value == null) return null;
    if (value is String && value.trim().isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) return parsed;
    }
    throw const FormatException('backupInvalidExportTime');
  }

  List<Object?> _list(Map<String, Object?> root, String key) {
    final value = root[key];
    if (value is List) return value.cast<Object?>();
    throw const FormatException('backupMissingData');
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw const FormatException('backupInvalidRow');
  }

  String _string(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw const FormatException('backupMissingField');
  }

  int _positiveInt(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is int && value > 0) return value;
    throw const FormatException('backupPositiveNumberRequired');
  }

  int _nonNegativeInt(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is int && value >= 0) return value;
    throw const FormatException('backupNonNegativeNumberRequired');
  }

  bool _bool(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is bool) return value;
    throw const FormatException('backupMissingField');
  }

  WalletType _walletType(Map<String, Object?> item, String key) {
    try {
      return WalletType.values.byName(_string(item, key));
    } on ArgumentError {
      throw const FormatException('backupInvalidType');
    }
  }

  TransactionType _transactionType(Map<String, Object?> item, String key) {
    try {
      return TransactionType.values.byName(_string(item, key));
    } on ArgumentError {
      throw const FormatException('backupInvalidType');
    }
  }

  DateTime _dateTime(Map<String, Object?> item, String key) {
    final parsed = DateTime.tryParse(_string(item, key));
    if (parsed != null) return parsed;
    throw const FormatException('backupInvalidDate');
  }

  void _validateIds(Iterable<String> ids) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) throw const FormatException('backupDuplicateId');
    }
  }

  void _validateReferences({
    required List<WalletAccount> wallets,
    required List<FinanceCategory> categories,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
  }) {
    final walletIds = wallets.map((item) => item.id).toSet();
    final categoryIds = categories.map((item) => item.id).toSet();
    for (final transaction in transactions) {
      if (!walletIds.contains(transaction.walletId)) {
        throw const FormatException('backupMissingWalletReference');
      }
      final targetId = transaction.toWalletId;
      if (targetId != null && !walletIds.contains(targetId)) {
        throw const FormatException('backupMissingTargetWalletReference');
      }
      if (!categoryIds.contains(transaction.categoryId)) {
        throw const FormatException('backupMissingCategoryReference');
      }
    }
    for (final budget in budgets) {
      if (!categoryIds.contains(budget.categoryId)) {
        throw const FormatException('backupMissingCategoryReference');
      }
    }
  }
}
