part of 'local_finance_store.dart';

void _assertWalletExists(Database db, String walletId) {
  final rows = db.select('select id from wallets where id = ? limit 1', [
    walletId,
  ]);
  if (rows.isEmpty) {
    throw ArgumentError.value(walletId, 'walletId', 'Wallet does not exist');
  }
}

void _assertCategoryExists(
  Database db,
  String categoryId, {
  TransactionType? expectedType,
}) {
  final rows = db.select('select type from categories where id = ? limit 1', [
    categoryId,
  ]);
  if (rows.isEmpty) {
    throw ArgumentError.value(
      categoryId,
      'categoryId',
      'Category does not exist',
    );
  }
  if (expectedType != null && rows.first['type'] != expectedType.name) {
    throw ArgumentError.value(
      categoryId,
      'categoryId',
      'Category type mismatch',
    );
  }
}

void _assertBudgetMonthFirstDay(DateTime month) {
  if (month.day != 1) {
    throw ArgumentError.value(month, 'month', 'Budget month must be first day');
  }
}

void _assertSavingGoalAmounts({
  required int targetAmount,
  required int savedAmount,
}) {
  if (targetAmount <= 0) {
    throw ArgumentError.value(
      targetAmount,
      'targetAmount',
      'Target must be positive',
    );
  }
  if (savedAmount < 0 || savedAmount > targetAmount) {
    throw ArgumentError.value(
      savedAmount,
      'savedAmount',
      'Saved amount must be between zero and target',
    );
  }
}
