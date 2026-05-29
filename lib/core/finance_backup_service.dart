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

  FinanceBackupData decode(String input) {
    final root = jsonDecode(input);
    if (root is! Map<String, Object?>) {
      throw const FormatException('File backup không hợp lệ');
    }
    if (root['app'] != 'cashflow_manager' || root['schemaVersion'] != 1) {
      throw const FormatException('Phiên bản backup không được hỗ trợ');
    }
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
      throw const FormatException('Backup phải có ít nhất một ví');
    }
    if (categories.isEmpty) {
      throw const FormatException('Backup phải có ít nhất một danh mục');
    }
    _validateIds(wallets.map((item) => item.id), 'ví');
    _validateIds(categories.map((item) => item.id), 'danh mục');
    _validateIds(transactions.map((item) => item.id), 'giao dịch');
    _validateIds(budgets.map((item) => item.id), 'ngân sách');
    _validateIds(goals.map((item) => item.id), 'mục tiêu');
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
      type: WalletType.values.byName(_string(item, 'type')),
      initialBalance: _nonNegativeInt(item, 'initialBalance'),
    );
  }

  FinanceCategory _categoryFromJson(Object? value) {
    final item = _map(value);
    return FinanceCategory(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      type: TransactionType.values.byName(_string(item, 'type')),
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
      type: TransactionType.values.byName(_string(item, 'type')),
      amount: _positiveInt(item, 'amount'),
      date: DateTime.parse(_string(item, 'date')),
      note: _string(item, 'note'),
      isRecurring: _bool(item, 'isRecurring'),
    );
  }

  Budget _budgetFromJson(Object? value) {
    final item = _map(value);
    return Budget(
      id: _string(item, 'id'),
      categoryId: _string(item, 'categoryId'),
      month: DateTime.parse(_string(item, 'month')),
      limitAmount: _positiveInt(item, 'limitAmount'),
    );
  }

  SavingGoal _goalFromJson(Object? value) {
    final item = _map(value);
    final targetAmount = _positiveInt(item, 'targetAmount');
    final savedAmount = _nonNegativeInt(item, 'savedAmount');
    if (savedAmount > targetAmount) {
      throw const FormatException('Số tiền đã tiết kiệm vượt mục tiêu');
    }
    return SavingGoal(
      id: _string(item, 'id'),
      name: _string(item, 'name'),
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: DateTime.parse(_string(item, 'deadline')),
    );
  }

  List<Object?> _list(Map<String, Object?> root, String key) {
    final value = root[key];
    if (value is List) return value.cast<Object?>();
    throw FormatException('Thiếu dữ liệu $key');
  }

  Map<String, Object?> _map(Object? value) {
    if (value is Map<String, Object?>) return value;
    throw const FormatException('Dòng dữ liệu backup không hợp lệ');
  }

  String _string(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Thiếu trường $key');
  }

  int _positiveInt(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is int && value > 0) return value;
    throw FormatException('$key phải lớn hơn 0');
  }

  int _nonNegativeInt(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is int && value >= 0) return value;
    throw FormatException('$key không được âm');
  }

  bool _bool(Map<String, Object?> item, String key) {
    final value = item[key];
    if (value is bool) return value;
    throw FormatException('Thiếu trường $key');
  }

  void _validateIds(Iterable<String> ids, String label) {
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) throw FormatException('Trùng mã $label: $id');
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
        throw FormatException(
          'Giao dịch tham chiếu ví không tồn tại: ${transaction.walletId}',
        );
      }
      final targetId = transaction.toWalletId;
      if (targetId != null && !walletIds.contains(targetId)) {
        throw FormatException(
          'Giao dịch tham chiếu ví nhận không tồn tại: $targetId',
        );
      }
      if (!categoryIds.contains(transaction.categoryId)) {
        throw FormatException(
          'Giao dịch tham chiếu danh mục không tồn tại: ${transaction.categoryId}',
        );
      }
    }
    for (final budget in budgets) {
      if (!categoryIds.contains(budget.categoryId)) {
        throw FormatException(
          'Ngân sách tham chiếu danh mục không tồn tại: ${budget.categoryId}',
        );
      }
    }
  }
}
