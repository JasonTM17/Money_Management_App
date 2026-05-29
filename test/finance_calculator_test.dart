import 'package:cashflow_manager/core/finance_calculator.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/core/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseVndAmount rejects empty zero and negative values', () {
    expect(() => parseVndAmount(''), throwsFormatException);
    expect(() => parseVndAmount('0'), throwsFormatException);
    expect(parseVndAmount('1.250.000 ₫'), 1250000);
  });

  test('wallet balances include income expense and transfer', () {
    final wallets = [
      const WalletAccount(
        id: 'cash',
        name: 'Tiền mặt',
        type: WalletType.cash,
        initialBalance: 1000000,
      ),
      const WalletAccount(
        id: 'bank',
        name: 'Ngân hàng',
        type: WalletType.bank,
        initialBalance: 2000000,
      ),
    ];
    final transactions = [
      FinanceTransaction(
        id: 'income',
        walletId: 'bank',
        categoryId: 'salary',
        type: TransactionType.income,
        amount: 500000,
        date: DateTime(2026, 5),
        note: '',
      ),
      FinanceTransaction(
        id: 'expense',
        walletId: 'cash',
        categoryId: 'food',
        type: TransactionType.expense,
        amount: 200000,
        date: DateTime(2026, 5),
        note: '',
      ),
      FinanceTransaction(
        id: 'transfer',
        walletId: 'bank',
        toWalletId: 'cash',
        categoryId: 'transfer',
        type: TransactionType.transfer,
        amount: 300000,
        date: DateTime(2026, 5),
        note: '',
      ),
    ];

    final balances = const FinanceCalculator().walletBalances(
      wallets: wallets,
      transactions: transactions,
    );

    expect(balances['cash'], 1100000);
    expect(balances['bank'], 2200000);
  });

  test('dashboard summary detects budget warning and empty month totals', () {
    final month = DateTime(2026, 5);
    final summary = const FinanceCalculator().dashboardSummary(
      wallets: const [
        WalletAccount(
          id: 'cash',
          name: 'Tiền mặt',
          type: WalletType.cash,
          initialBalance: 1000000,
        ),
      ],
      transactions: [
        FinanceTransaction(
          id: 'expense',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 900000,
          date: month,
          note: '',
        ),
      ],
      budgets: [
        Budget(
          id: 'budget',
          categoryId: 'food',
          month: month,
          limitAmount: 1000000,
        ),
      ],
      month: month,
    );

    expect(summary.monthIncome, 0);
    expect(summary.monthExpense, 900000);
    expect(summary.budgetAlerts, ['food']);
  });

  test('saving goal monthly suggestion uses remaining months', () {
    final goal = SavingGoal(
      id: 'g',
      name: 'Quỹ',
      targetAmount: 12000000,
      savedAmount: 3000000,
      deadline: DateTime(2026, 8),
    );

    expect(
      const FinanceCalculator().requiredMonthlySaving(goal, DateTime(2026, 5)),
      3000000,
    );
  });

  test(
    'categorySpend only counts matching expense items in selected month',
    () {
      final transactions = [
        FinanceTransaction(
          id: 'food',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 100000,
          date: DateTime(2026, 5),
          note: '',
        ),
        FinanceTransaction(
          id: 'salary',
          walletId: 'cash',
          categoryId: 'salary',
          type: TransactionType.income,
          amount: 100000,
          date: DateTime(2026, 5),
          note: '',
        ),
        FinanceTransaction(
          id: 'old',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 50000,
          date: DateTime(2026, 4),
          note: '',
        ),
      ];

      expect(
        const FinanceCalculator().categorySpend(
          transactions: transactions,
          categoryId: 'food',
          month: DateTime(2026, 5),
        ),
        100000,
      );
    },
  );
}
