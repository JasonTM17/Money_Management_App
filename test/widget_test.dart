import 'package:cashflow_manager/core/finance_calculator.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/data/local_finance_store.dart';
import 'package:cashflow_manager/features/home/finance_controller.dart';
import 'package:cashflow_manager/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeFinanceStore extends LocalFinanceStore {
  @override
  Future<FinanceState> load() async {
    final wallets = const [WalletAccount(id: 'cash', name: 'Tiền mặt', type: WalletType.cash, initialBalance: 1000000)];
    final categories = const [FinanceCategory(id: 'food', name: 'Ăn uống', type: TransactionType.expense, colorHex: 0xFFFF9800)];
    final transactions = [FinanceTransaction(id: 'txn', walletId: 'cash', categoryId: 'food', type: TransactionType.expense, amount: 50000, date: DateTime(2026, 5), note: 'Ăn sáng')];
    final summary = const FinanceCalculator().dashboardSummary(wallets: wallets, transactions: transactions, budgets: const [], month: DateTime(2026, 5));
    return FinanceState(wallets: wallets, categories: categories, transactions: transactions, budgets: const [], goals: const [], summary: summary);
  }
}

void main() {
  testWidgets('shows CashFlow Manager dashboard shell', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeStoreProvider.overrideWithValue(FakeFinanceStore())],
        child: const CashFlowManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CashFlow Manager'), findsOneWidget);
    expect(find.text('Thêm giao dịch'), findsOneWidget);
    expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
  });
}
