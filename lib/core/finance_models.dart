enum TransactionType { income, expense, transfer }

enum WalletType { cash, bank, eWallet, creditCard }

class WalletAccount {
  const WalletAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.initialBalance,
  });

  final String id;
  final String name;
  final WalletType type;
  final int initialBalance;
}

class FinanceCategory {
  const FinanceCategory({
    required this.id,
    required this.name,
    required this.type,
    required this.colorHex,
  });

  final String id;
  final String name;
  final TransactionType type;
  final int colorHex;
}

class FinanceTransaction {
  const FinanceTransaction({
    required this.id,
    required this.walletId,
    required this.categoryId,
    required this.type,
    required this.amount,
    required this.date,
    required this.note,
    this.toWalletId,
    this.isRecurring = false,
  });

  final String id;
  final String walletId;
  final String? toWalletId;
  final String categoryId;
  final TransactionType type;
  final int amount;
  final DateTime date;
  final String note;
  final bool isRecurring;
}

class Budget {
  const Budget({
    required this.id,
    required this.categoryId,
    required this.month,
    required this.limitAmount,
  });

  final String id;
  final String categoryId;
  final DateTime month;
  final int limitAmount;
}

class SavingGoal {
  const SavingGoal({
    required this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.deadline,
  });

  final String id;
  final String name;
  final int targetAmount;
  final int savedAmount;
  final DateTime deadline;
}

class DashboardSummary {
  const DashboardSummary({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.netCashflow,
    required this.budgetAlerts,
  });

  final int totalBalance;
  final int monthIncome;
  final int monthExpense;
  final int netCashflow;
  final List<String> budgetAlerts;
}
