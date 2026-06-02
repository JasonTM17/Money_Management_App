import '../core/finance_backup_service.dart';
import '../core/finance_models.dart';
import 'local_store_core.dart';
import 'local_store_migration.dart';
import 'local_store_sync_operations.dart';

class BackupRestoreOperations {
  BackupRestoreOperations(
    this._core,
    this._migration,
    this._sync,
  );

  final FinanceStoreCore _core;
  final MigrationOperations _migration;
  final SyncOperations _sync;

  Future<String> exportBackup() async {
    final state = await _buildState();
    return const FinanceBackupService().encode(
      wallets: state.wallets,
      categories: state.categories,
      transactions: state.transactions,
      budgets: state.budgets,
      goals: state.goals,
    );
  }

  Future<String> exportEncryptedBackup(String passphrase) async {
    final state = await _buildState();
    return const FinanceBackupService().encodeEncrypted(
      wallets: state.wallets,
      categories: state.categories,
      transactions: state.transactions,
      budgets: state.budgets,
      goals: state.goals,
      passphrase: passphrase,
    );
  }

  Future<void> restoreBackup(String input) async {
    final backup = const FinanceBackupService().decode(input);
    final db = await _core.open();
    db.execute('begin immediate');
    try {
      _migration.deleteAllData(db);
      _sync.deleteAllSyncState(db);
      for (final wallet in backup.wallets) {
        db.execute('insert into wallets values (?, ?, ?, ?)', [
          wallet.id, wallet.name, wallet.type.name, wallet.initialBalance,
        ]);
      }
      for (final category in backup.categories) {
        db.execute('insert into categories values (?, ?, ?, ?)', [
          category.id, category.name, category.type.name, category.colorHex,
        ]);
      }
      for (final transaction in backup.transactions) {
        db.execute('insert into transactions values (?, ?, ?, ?, ?, ?, ?, ?, ?)', [
          transaction.id, transaction.walletId, transaction.toWalletId,
          transaction.categoryId, transaction.type.name, transaction.amount,
          transaction.date.toIso8601String(), transaction.note,
          transaction.isRecurring ? 1 : 0,
        ]);
      }
      for (final budget in backup.budgets) {
        db.execute('insert into budgets values (?, ?, ?, ?)', [
          budget.id, budget.categoryId, budget.month.toIso8601String(), budget.limitAmount,
        ]);
      }
      for (final goal in backup.goals) {
        db.execute('insert into saving_goals values (?, ?, ?, ?, ?)', [
          goal.id, goal.name, goal.targetAmount, goal.savedAmount, goal.deadline.toIso8601String(),
        ]);
      }
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<({List<WalletAccount> wallets, List<FinanceCategory> categories, List<FinanceTransaction> transactions, List<Budget> budgets, List<SavingGoal> goals})> _buildState() async {
    final db = await _core.open();
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
    return (wallets: wallets, categories: categories, transactions: transactions, budgets: budgets, goals: goals);
  }
}

