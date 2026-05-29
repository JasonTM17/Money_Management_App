import 'finance_models.dart';

class FinanceCalculator {
  const FinanceCalculator();

  Map<String, int> walletBalances({
    required List<WalletAccount> wallets,
    required List<FinanceTransaction> transactions,
  }) {
    final balances = {for (final wallet in wallets) wallet.id: wallet.initialBalance};
    for (final transaction in transactions) {
      if (!balances.containsKey(transaction.walletId)) continue;
      switch (transaction.type) {
        case TransactionType.income:
          balances[transaction.walletId] = balances[transaction.walletId]! + transaction.amount;
        case TransactionType.expense:
          balances[transaction.walletId] = balances[transaction.walletId]! - transaction.amount;
        case TransactionType.transfer:
          final targetId = transaction.toWalletId;
          if (targetId == null || !balances.containsKey(targetId)) continue;
          balances[transaction.walletId] = balances[transaction.walletId]! - transaction.amount;
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
    final balances = walletBalances(wallets: wallets, transactions: transactions);
    final monthItems = transactions.where((item) => item.date.year == month.year && item.date.month == month.month);
    final income = monthItems.where((item) => item.type == TransactionType.income).fold(0, (sum, item) => sum + item.amount);
    final expense = monthItems.where((item) => item.type == TransactionType.expense).fold(0, (sum, item) => sum + item.amount);
    final alerts = <String>[];
    for (final budget in budgets.where((item) => item.month.year == month.year && item.month.month == month.month)) {
      final spent = monthItems
          .where((item) => item.type == TransactionType.expense && item.categoryId == budget.categoryId)
          .fold(0, (sum, item) => sum + item.amount);
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
    final monthCount = ((goal.deadline.year - now.year) * 12 + goal.deadline.month - now.month).clamp(1, 1200);
    return (remaining / monthCount).ceil();
  }

  int forecastEndBalance({
    required int currentBalance,
    required List<FinanceTransaction> recurringTransactions,
    required DateTime until,
    required DateTime now,
  }) {
    var balance = currentBalance;
    final months = ((until.year - now.year) * 12 + until.month - now.month).clamp(0, 1200) + 1;
    for (final transaction in recurringTransactions.where((item) => item.isRecurring)) {
      final signedAmount = switch (transaction.type) {
        TransactionType.income => transaction.amount,
        TransactionType.expense => -transaction.amount,
        TransactionType.transfer => 0,
      };
      balance += signedAmount * months;
    }
    return balance;
  }
}
