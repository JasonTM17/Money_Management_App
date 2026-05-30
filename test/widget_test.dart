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
  FakeFinanceStore()
    : _transactions = List.of(_defaultTransactions),
      _budgets = List.of(_defaultBudgets),
      _goals = <SavingGoal>[];

  FakeFinanceStore.withTransfer()
    : _transactions = [
        FinanceTransaction(
          id: 'txn-transfer',
          walletId: 'bank',
          toWalletId: 'cash',
          categoryId: 'transfer',
          type: TransactionType.transfer,
          amount: 250000,
          date: DateTime(2026, 5),
          note: 'Chuyển tiền',
        ),
        ..._defaultTransactions,
      ],
      _budgets = List.of(_defaultBudgets),
      _goals = <SavingGoal>[];

  FakeFinanceStore.withReportInsights()
    : _transactions = [
        FinanceTransaction(
          id: 'txn-bill',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 300000,
          date: DateTime(2026, 5, 15),
          note: 'Tiền điện',
          isRecurring: true,
        ),
        ..._defaultTransactions,
      ],
      _budgets = List.of(_defaultBudgets),
      _goals = <SavingGoal>[];

  late List<FinanceTransaction> _transactions;
  late List<Budget> _budgets;
  late List<SavingGoal> _goals;

  static final _defaultTransactions = [
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

  static final _defaultBudgets = [
    Budget(
      id: 'budget-food',
      categoryId: 'food',
      month: DateTime(2026, 5),
      limitAmount: 100000,
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
      FinanceCategory(
        id: 'transfer',
        name: 'Chuyển ví',
        type: TransactionType.transfer,
        colorHex: 0xFF16A34A,
      ),
    ];
    final summary = const FinanceCalculator().dashboardSummary(
      wallets: wallets,
      transactions: _transactions,
      budgets: _budgets,
      month: DateTime(2026, 5),
    );
    return FinanceState(
      wallets: wallets,
      categories: categories,
      transactions: _transactions,
      budgets: _budgets,
      goals: _goals,
      summary: summary,
      reportMonth: DateTime(2026, 5),
    );
  }

  @override
  Future<void> deleteTransaction(String id) async {
    _transactions = _transactions.where((item) => item.id != id).toList();
  }

  @override
  Future<void> upsertBudget({
    required String categoryId,
    required DateTime month,
    required int limitAmount,
  }) async {
    final monthKey = DateTime(month.year, month.month);
    final existing = _budgets.indexWhere(
      (item) =>
          item.categoryId == categoryId &&
          item.month.year == monthKey.year &&
          item.month.month == monthKey.month,
    );
    final budget = Budget(
      id: existing == -1
          ? 'budget-${_budgets.length + 1}'
          : _budgets[existing].id,
      categoryId: categoryId,
      month: monthKey,
      limitAmount: limitAmount,
    );
    if (existing == -1) {
      _budgets = [..._budgets, budget];
      return;
    }
    _budgets = [
      for (final item in _budgets) item.id == budget.id ? budget : item,
    ];
  }

  @override
  Future<void> updateBudget({
    required String id,
    required String categoryId,
    required DateTime month,
    required int limitAmount,
  }) async {
    final monthKey = DateTime(month.year, month.month);
    _budgets = [
      for (final item in _budgets)
        item.id == id
            ? Budget(
                id: id,
                categoryId: categoryId,
                month: monthKey,
                limitAmount: limitAmount,
              )
            : item,
    ];
  }

  @override
  Future<void> deleteBudget(String id) async {
    _budgets = _budgets.where((item) => item.id != id).toList();
  }

  @override
  Future<void> saveGoal({
    String? id,
    required String name,
    required int targetAmount,
    required int savedAmount,
    required DateTime deadline,
  }) async {
    final goal = SavingGoal(
      id: id ?? 'goal-${_goals.length + 1}',
      name: name.trim(),
      targetAmount: targetAmount,
      savedAmount: savedAmount,
      deadline: deadline,
    );
    _goals = id == null
        ? [..._goals, goal]
        : [for (final item in _goals) item.id == id ? goal : item];
  }

  @override
  Future<void> deleteGoal(String id) async {
    _goals = _goals.where((item) => item.id != id).toList();
  }

  @override
  Future<void> transfer({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    required DateTime date,
    required String note,
  }) async {
    _transactions = [
      FinanceTransaction(
        id: 'transfer',
        walletId: fromWalletId,
        toWalletId: toWalletId,
        categoryId: 'transfer',
        type: TransactionType.transfer,
        amount: amount,
        date: date,
        note: note,
      ),
      ..._transactions,
    ];
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

  testWidgets('creates and deletes a monthly budget', (tester) async {
    final store = FakeFinanceStore();
    await _pumpApp(tester, store: store);

    await tester.tap(find.text('Ngân sách'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm ngân sách'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Hạn mức tháng'),
      '250000',
    );
    await tester.tap(find.text('Lưu ngân sách'));
    await tester.pumpAndSettle();

    expect(find.textContaining('250.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa ngân sách').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('250.000'), findsNothing);
  });

  testWidgets('creates and deletes a saving goal', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm mục tiêu'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Tên mục tiêu'),
      'Du lịch',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Số tiền mục tiêu'),
      '3000000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Đã tiết kiệm'),
      '500000',
    );
    await tester.tap(find.text('Lưu mục tiêu'));
    await tester.pumpAndSettle();

    expect(find.text('Du lịch'), findsOneWidget);
    expect(find.textContaining('2.500.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa mục tiêu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(find.text('Du lịch'), findsNothing);
  });

  testWidgets('transfers money between wallets from wallet tab', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển tiền giữa ví'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '100000');
    await tester.tap(find.text('Thực hiện chuyển ví'));
    await tester.pumpAndSettle();

    expect(find.textContaining('850.000'), findsOneWidget);
    expect(find.textContaining('20.100.000'), findsOneWidget);
  });

  testWidgets('shows Vietnamese validation for same-wallet transfer', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển tiền giữa ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiền mặt').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '100000');
    await tester.tap(find.text('Thực hiện chuyển ví'));
    await tester.pumpAndSettle();

    expect(find.text('Ví nguồn và ví nhận phải khác nhau'), findsOneWidget);
  });

  testWidgets('changes theme mode from settings', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tối'));
    await tester.pumpAndSettle();

    expect(find.text('Giao diện'), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);
  });

  testWidgets('filters transactions by search query', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ăn uống');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Lương'), findsNothing);
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

  testWidgets('does not open income expense editor for transfers', (
    tester,
  ) async {
    await _pumpApp(tester, store: FakeFinanceStore.withTransfer());

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Chuyển tiền').first);
    await tester.pumpAndSettle();

    expect(find.text('Lưu giao dịch'), findsNothing);
  });

  testWidgets('shows populated report insights and forecast cards', (
    tester,
  ) async {
    await _pumpApp(tester, store: FakeFinanceStore.withReportInsights());

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();

    expect(find.text('Chi tiêu theo danh mục'), findsOneWidget);
    expect(find.textContaining('Ăn uống: 350.000'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Top category chi tiêu'), 300);
    expect(find.text('Ăn uống'), findsWidgets);
    expect(find.textContaining('350.000'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Dự báo dòng tiền'), 300);
    expect(find.text('Nhắc hóa đơn sắp tới'), findsOneWidget);
    expect(find.text('Tiền điện'), findsOneWidget);
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

  testWidgets('opens backup restore sheet from settings', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Cài đặt'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Backup / restore'), 300);
    await tester.tap(find.text('Backup / restore'));
    await tester.pumpAndSettle();

    expect(find.text('Backup / restore dữ liệu'), findsOneWidget);
    expect(find.text('Xuất backup JSON'), findsOneWidget);
    expect(find.text('Khôi phục từ file JSON'), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester, {FakeFinanceStore? store}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeStoreProvider.overrideWithValue(store ?? FakeFinanceStore()),
        privacyLockBypassProvider.overrideWithValue(true),
      ],
      child: const CashFlowManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
}
