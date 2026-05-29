import 'finance_models.dart';

class FinanceCalculator {
  const FinanceCalculator();

  Map<String, int> walletBalances({
    required List<WalletAccount> wallets,
    required List<FinanceTransaction> transactions,
  }) {
    final balances = {
      for (final wallet in wallets) wallet.id: wallet.initialBalance,
    };
    for (final transaction in transactions) {
      if (!balances.containsKey(transaction.walletId)) continue;
      switch (transaction.type) {
        case TransactionType.income:
          balances[transaction.walletId] =
              balances[transaction.walletId]! + transaction.amount;
        case TransactionType.expense:
          balances[transaction.walletId] =
              balances[transaction.walletId]! - transaction.amount;
        case TransactionType.transfer:
          final targetId = transaction.toWalletId;
          if (targetId == null || !balances.containsKey(targetId)) continue;
          balances[transaction.walletId] =
              balances[transaction.walletId]! - transaction.amount;
          balances[targetId] = balances[targetId]! + transaction.amount;
      }
    }
    return balances;
  }

  DashboardSummary dashboardSummary({
    required List<WalletAccount> wallets,
    required List<FinanceTransaction> transactions,
    required List<Budget> budgets,
    required DateTime month,
  }) {
    final balances = walletBalances(
      wallets: wallets,
      transactions: transactions,
    );
    final monthItems = transactions.where(
      (item) => item.date.year == month.year && item.date.month == month.month,
    );
    final income = monthItems
        .where((item) => item.type == TransactionType.income)
        .fold(0, (sum, item) => sum + item.amount);
    final expense = monthItems
        .where((item) => item.type == TransactionType.expense)
        .fold(0, (sum, item) => sum + item.amount);
    final alerts = <String>[];
    for (final budget in budgets.where(
      (item) =>
          item.month.year == month.year && item.month.month == month.month,
    )) {
      final spent = categorySpend(
        transactions: transactions,
        categoryId: budget.categoryId,
        month: month,
      );
      if (spent >= budget.limitAmount * 0.9) {
        alerts.add(budget.categoryId);
      }
    }
    return DashboardSummary(
      totalBalance: balances.values.fold(0, (sum, amount) => sum + amount),
      monthIncome: income,
      monthExpense: expense,
      netCashflow: income - expense,
      budgetAlerts: alerts,
    );
  }

  int requiredMonthlySaving(SavingGoal goal, DateTime now) {
    final remaining = goal.targetAmount - goal.savedAmount;
    if (remaining <= 0) return 0;
    final monthCount =
        ((goal.deadline.year - now.year) * 12 + goal.deadline.month - now.month)
            .clamp(1, 1200);
    return (remaining / monthCount).ceil();
  }

  int categorySpend({
    required List<FinanceTransaction> transactions,
    required String categoryId,
    required DateTime month,
  }) {
    return transactions
        .where(
          (item) =>
              item.type == TransactionType.expense &&
              item.categoryId == categoryId &&
              item.date.year == month.year &&
              item.date.month == month.month,
        )
        .fold(0, (sum, item) => sum + item.amount);
  }

  int forecastEndBalance({
    required int currentBalance,
    required List<FinanceTransaction> recurringTransactions,
    required DateTime until,
    required DateTime now,
  }) {
    var balance = currentBalance;
    for (final transaction in recurringTransactions.where(
      (item) => item.isRecurring,
    )) {
      final signedAmount = switch (transaction.type) {
        TransactionType.income => transaction.amount,
        TransactionType.expense => -transaction.amount,
        TransactionType.transfer => 0,
      };
      balance += signedAmount * _futureOccurrenceCount(transaction, now, until);
    }
    return balance;
  }

  int _futureOccurrenceCount(
    FinanceTransaction transaction,
    DateTime now,
    DateTime until,
  ) {
    if (!until.isAfter(now)) return 0;
    var count = 0;
    var cursor = DateTime(now.year, now.month);
    final endMonth = DateTime(until.year, until.month);
    while (!cursor.isAfter(endMonth)) {
      final day = transaction.date.day.clamp(
        1,
        DateTime(cursor.year, cursor.month + 1, 0).day,
      );
      final occurrence = DateTime(cursor.year, cursor.month, day);
      if (occurrence.isAfter(now) && !occurrence.isAfter(until)) count++;
      cursor = DateTime(cursor.year, cursor.month + 1);
    }
    return count;
  }
}
