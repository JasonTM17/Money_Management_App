import 'package:sqlite3/sqlite3.dart';

import '../core/finance_calculator.dart';
import '../core/finance_models.dart';
import '../core/sync_models.dart';

import 'local_store_backup_restore.dart';
import 'local_store_budget_operations.dart';
import 'local_store_core.dart';
import 'local_store_goal_operations.dart';
import 'local_store_migration.dart';
import 'local_store_sync_operations.dart';
import 'local_store_transaction_operations.dart';
import 'local_store_validation.dart';

class FinanceState {
  const FinanceState({
    required this.wallets,
    required this.categories,
    required this.transactions,
    required this.budgets,
    required this.goals,
    required this.summary,
    required this.reportMonth,
  });

  final List<WalletAccount> wallets;
  final List<FinanceCategory> categories;
  final List<FinanceTransaction> transactions;
  final List<Budget> budgets;
  final List<SavingGoal> goals;
  final DashboardSummary summary;
  final DateTime reportMonth;
}

class LocalFinanceStore {
  LocalFinanceStore({String? databasePath})
    : _core = FinanceStoreCore(databasePath: databasePath);

  final FinanceStoreCore _core;
  final FinanceCalculator _calculator = const FinanceCalculator();
  bool _initialized = false;

  late final MigrationOperations _migration = MigrationOperations(_core);
  late final SyncOperations _sync = SyncOperations(_core);
  late final ValidationOperations _validation = ValidationOperations();
  late final TransactionOperations _transactions = TransactionOperations(
    _core, _sync, _validation,
  );
  late final BudgetOperations _budgets = BudgetOperations(
    _core, _sync, _validation,
  );
  late final GoalOperations _goals = GoalOperations(
    _core, _sync, _validation,
  );
  late final BackupRestoreOperations _backup = BackupRestoreOperations(
    _core, _migration, _sync,
  );

  Future<Database> _open() async {
    final db = await _core.open();
    if (!_initialized) {
      _migration.runMigration(db);
      _migration.seed(db);
      _migration.repairMojibake(db);
      _initialized = true;
    }
    return db;
  }

  Future<FinanceState> load() async {
    final db = await _open();
    return _stateFromDb(db);
  }

  Future<void> resetData() async {
    final db = await _open();
    db.execute('begin immediate');
    try {
      _migration.deleteAllData(db);
      _sync.deleteAllSyncState(db);
      _migration.seed(db);
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> addTransaction({
    required TransactionType type,
    required String walletId,
    required String categoryId,
    required int amount,
    required DateTime date,
    required String note,
    bool isRecurring = false,
  }) => _transactions.addTransaction(
    type: type, walletId: walletId, categoryId: categoryId,
    amount: amount, date: date, note: note, isRecurring: isRecurring,
  );

  Future<void> updateTransaction({
    required String id,
    required TransactionType type,
    required String walletId,
    required String categoryId,
    required int amount,
    required DateTime date,
    required String note,
    bool isRecurring = false,
  }) => _transactions.updateTransaction(
    id: id, type: type, walletId: walletId, categoryId: categoryId,
    amount: amount, date: date, note: note, isRecurring: isRecurring,
  );

  Future<void> deleteTransaction(String id) =>
      _transactions.deleteTransaction(id);

  Future<void> transfer({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    required DateTime date,
    required String note,
  }) => _transactions.transfer(
    fromWalletId: fromWalletId, toWalletId: toWalletId,
    amount: amount, date: date, note: note,
  );

  Future<void> upsertBudget({
    required String categoryId,
    required DateTime month,
    required int limitAmount,
  }) => _budgets.upsertBudget(
    categoryId: categoryId, month: month, limitAmount: limitAmount,
  );

  Future<void> updateBudget({
    required String id,
    required String categoryId,
    required DateTime month,
    required int limitAmount,
  }) => _budgets.updateBudget(
    id: id, categoryId: categoryId, month: month, limitAmount: limitAmount,
  );

  Future<void> deleteBudget(String id) => _budgets.deleteBudget(id);

  Future<void> deleteGoal(String id) => _goals.deleteGoal(id);

  Future<void> saveGoal({
    String? id,
    required String name,
    required int targetAmount,
    required int savedAmount,
    required DateTime deadline,
  }) => _goals.saveGoal(
    id: id, name: name, targetAmount: targetAmount,
    savedAmount: savedAmount, deadline: deadline,
  );

  // --- Sync public API ---

  Future<LocalSyncStatus> loadSyncStatus() => _sync.loadSyncStatus();

  Future<List<RemoteSyncMutation>> pendingRemoteMutations({int limit = 100}) =>
      _sync.pendingRemoteMutations(limit: limit);

  Future<void> saveSyncServerMapping({
    required String entityType,
    required String localId,
    required String serverId,
    int revision = 0,
  }) => _sync.saveSyncServerMapping(
    entityType: entityType, localId: localId,
    serverId: serverId, revision: revision,
  );

  Future<void> markSyncPushResult(RemoteSyncPushResponse response) =>
      _sync.markSyncPushResult(response);

  Future<void> saveSyncCursor(String cursor) => _sync.saveSyncCursor(cursor);

  // --- Backup/restore public API ---

  Future<String> exportBackup() => _backup.exportBackup();

  Future<String> exportEncryptedBackup(String passphrase) =>
      _backup.exportEncryptedBackup(passphrase);

  Future<void> restoreBackup(String input) => _backup.restoreBackup(input);

  // --- Internal ---

  FinanceState _stateFromDb(Database db) {
    final wallets = db
        .select('select * from wallets order by name')
        .map(_core.walletFromRow)
        .toList();
    final categories = db
        .select('select * from categories order by type, name')
        .map(_core.categoryFromRow)
        .toList();
    final transactions = db
        .select('select * from transactions order by date desc')
        .map(_core.transactionFromRow)
        .toList();
    final budgets = db
        .select('select * from budgets')
        .map(_core.budgetFromRow)
        .toList();
    final goals = db
        .select('select * from saving_goals order by deadline')
        .map(_core.goalFromRow)
        .toList();
    final reportMonth = DateTime.now();
    final summary = _calculator.dashboardSummary(
      wallets: wallets,
      transactions: transactions,
      budgets: budgets,
      month: reportMonth,
    );
    return FinanceState(
      wallets: wallets,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      summary: summary,
      reportMonth: reportMonth,
    );
  }
}
