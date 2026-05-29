import 'package:cashflow_manager/core/finance_calculator.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/core/privacy_lock_service.dart';
import 'package:cashflow_manager/data/local_finance_store.dart';
import 'package:cashflow_manager/features/auth/privacy_gate.dart';
import 'package:cashflow_manager/features/home/finance_controller.dart';
import 'package:cashflow_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePrivacyLockService extends PrivacyLockService {
  FakePrivacyLockService({this.initialPin});

  String? initialPin;

  @override
  Future<bool> get hasPin async => initialPin != null;

  @override
  Future<void> savePin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const FormatException('PIN phải có 4-6 chữ số');
    }
    initialPin = pin;
  }

  @override
  Future<bool> verifyPin(String pin) async => pin == initialPin;

  @override
  Future<bool> authenticateBiometric() async => false;
}

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
  testWidgets('sets up first-run PIN before showing dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeStoreProvider.overrideWithValue(FakeFinanceStore()),
          privacyLockServiceProvider.overrideWithValue(
            FakePrivacyLockService(),
          ),
        ],
        child: const CashFlowManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bảo vệ dữ liệu tài chính'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'PIN mới'), '1234');
    await tester.enterText(
      find.widgetWithText(TextField, 'Nhập lại PIN'),
      '1234',
    );
    await tester.tap(find.text('Tạo PIN'));
    await tester.pumpAndSettle();

    expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
  });

  testWidgets('unlocks existing PIN before showing dashboard', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          financeStoreProvider.overrideWithValue(FakeFinanceStore()),
          privacyLockServiceProvider.overrideWithValue(
            FakePrivacyLockService(initialPin: '4321'),
          ),
        ],
        child: const CashFlowManagerApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
    await tester.tap(find.text('Mở khóa'));
    await tester.pumpAndSettle();

    expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
  });

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

  testWidgets('opens report export preview with CSV content', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Xuất CSV/PDF'), 300);
    await tester.tap(find.text('Xuất CSV/PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung xuất báo cáo'), findsOneWidget);
    expect(
      find.textContaining('CashFlow Manager - Báo cáo tháng'),
      findsWidgets,
    );
    expect(find.textContaining('date,type,wallet_id'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeStoreProvider.overrideWithValue(FakeFinanceStore()),
        privacyLockBypassProvider.overrideWithValue(true),
      ],
      child: const CashFlowManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
}
