import 'package:cashflow_manager/core/finance_calculator.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/core/privacy_lock_service.dart';
import 'package:cashflow_manager/data/local_finance_store.dart';

class FakePrivacyLockService extends PrivacyLockService {
  FakePrivacyLockService({
    this.initialPin,
    this.biometricEnabled = false,
    this.biometricAvailable = true,
    this.biometricAuthenticated = true,
  });

  String? initialPin;
  bool biometricEnabled;
  bool biometricAvailable;
  bool biometricAuthenticated;
  var verifyCount = 0;
  var biometricAuthCount = 0;

  @override
  Future<bool> get hasPin async => initialPin != null;

  @override
  Future<bool> get isBiometricEnabled async => biometricEnabled;

  @override
  Future<bool> get canUseBiometrics async => biometricAvailable;

  @override
  Future<void> savePin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const FormatException('PIN phải có 4-6 chữ số');
    }
    initialPin = pin;
    biometricEnabled = false;
  }

  @override
  Future<bool> verifyPin(String pin) async {
    verifyCount++;
    return pin == initialPin;
  }

  @override
  Future<bool> enableBiometric({required String localizedReason}) async {
    biometricAuthCount++;
    if (!biometricAvailable || !biometricAuthenticated) return false;
    biometricEnabled = true;
    return true;
  }

  @override
  Future<void> disableBiometric() async {
    biometricEnabled = false;
  }

  @override
  Future<bool> authenticateBiometric({required String localizedReason}) async {
    biometricAuthCount++;
    return biometricEnabled && biometricAvailable && biometricAuthenticated;
  }
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

  FakeFinanceStore.withMultiMonthReports()
    : _transactions = [
        FinanceTransaction(
          id: 'txn-april-rent',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 700000,
          date: DateTime(2026, 4, 20),
          note: 'Tiền nhà tháng 4',
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
  Future<void> addTransaction({
    required TransactionType type,
    required String walletId,
    required String categoryId,
    required int amount,
    required DateTime date,
    required String note,
    bool isRecurring = false,
  }) async {
    _transactions = [
      FinanceTransaction(
        id: 'txn-${_transactions.length + 1}',
        walletId: walletId,
        categoryId: categoryId,
        type: type,
        amount: amount,
        date: date,
        note: note,
        isRecurring: isRecurring,
      ),
      ..._transactions,
    ];
  }

  @override
  Future<void> updateTransaction({
    required String id,
    required TransactionType type,
    required String walletId,
    required String categoryId,
    required int amount,
    required DateTime date,
    required String note,
    bool isRecurring = false,
  }) async {
    _transactions = [
      for (final item in _transactions)
        item.id == id
            ? FinanceTransaction(
                id: id,
                walletId: walletId,
                categoryId: categoryId,
                type: type,
                amount: amount,
                date: date,
                note: note,
                isRecurring: isRecurring,
              )
            : item,
    ];
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
  Future<void> resetData() async {
    _transactions = List.of(_defaultTransactions);
    _budgets = List.of(_defaultBudgets);
    _goals = <SavingGoal>[];
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
