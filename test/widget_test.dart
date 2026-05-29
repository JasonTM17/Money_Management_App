import 'package:cashflow_manager/core/finance_calculator.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/data/local_finance_store.dart';
import 'package:cashflow_manager/features/home/finance_controller.dart';
import 'package:cashflow_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFinanceStore extends LocalFinanceStore {
  var _transactions = [
    FinanceTransaction(
      id: 'txn-breakfast',
      walletId: 'cash',
      categoryId: 'food',
      type: TransactionType.expense,
      amount: 50000,
      date: DateTime(2026, 5),
      note: 'Ăn sáng',
    ),
    FinanceTransaction(
      id: 'txn-salary',
      walletId: 'bank',
      categoryId: 'salary',
      type: TransactionType.income,
      amount: 18000000,
      date: DateTime(2026, 5),
      note: 'Lương',
    ),
  ];

  @override
  Future<FinanceState> load() async {
    final wallets = const [
      WalletAccount(
        id: 'cash',
        name: 'Tiền mặt',
        type: WalletType.cash,
        initialBalance: 1000000,
      ),
      WalletAccount(
        id: 'bank',
        name: 'Ngân hàng',
        type: WalletType.bank,
        initialBalance: 2000000,
      ),
    ];
    final categories = const [
      FinanceCategory(
        id: 'food',
        name: 'Ăn uống',
        type: TransactionType.expense,
        colorHex: 0xFFFF9800,
      ),
      FinanceCategory(
        id: 'salary',
        name: 'Lương',
        type: TransactionType.income,
        colorHex: 0xFF2196F3,
      ),
    ];
    final budgets = [
      Budget(
        id: 'budget-food',
        categoryId: 'food',
        month: DateTime(2026, 5),
        limitAmount: 100000,
      ),
    ];
    final summary = const FinanceCalculator().dashboardSummary(
      wallets: wallets,
      transactions: _transactions,
      budgets: budgets,
      month: DateTime(2026, 5),
    );
    return FinanceState(
      wallets: wallets,
      categories: categories,
      transactions: _transactions,
      budgets: budgets,
      goals: const [],
      summary: summary,
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _transactions = _transactions.where((item) => item.id != id).toList();
  }
}

void main() {
  testWidgets('shows CashFlow Manager dashboard shell', (tester) async {
    await _pumpApp(tester);

    expect(find.text('CashFlow Manager'), findsOneWidget);
    expect(find.text('Thêm giao dịch'), findsOneWidget);
    expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
  });

  testWidgets('shows budget tab with progress copy', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Ngân sách'));
    await tester.pumpAndSettle();

    expect(find.text('Ngân sách tháng này'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.textContaining('50.000'), findsWidgets);
  });

  testWidgets('filters transactions by search query', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Lương');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Lương'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsNothing);
  });

  testWidgets('deletes a transaction after confirmation', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Xóa giao dịch').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(find.text('Ăn sáng'), findsNothing);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [financeStoreProvider.overrideWithValue(FakeFinanceStore())],
      child: const CashFlowManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
}
