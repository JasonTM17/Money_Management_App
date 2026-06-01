part of 'local_finance_store.dart';

extension LocalFinanceStoreBackupRestore on LocalFinanceStore {
  Future<String> exportBackup() async {
    final state = await load();
    return const FinanceBackupService().encode(
      wallets: state.wallets,
      categories: state.categories,
      transactions: state.transactions,
      budgets: state.budgets,
      goals: state.goals,
    );
  }

  Future<String> exportEncryptedBackup(String passphrase) async {
    final state = await load();
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
    final db = await _open();
    db.execute('begin immediate');
    try {
      _deleteAllData(db);
      _deleteAllSyncState(db);
      for (final wallet in backup.wallets) {
        db.execute('insert into wallets values (?, ?, ?, ?)', [
          wallet.id,
          wallet.name,
          wallet.type.name,
          wallet.initialBalance,
        ]);
      }
      for (final category in backup.categories) {
        db.execute('insert into categories values (?, ?, ?, ?)', [
          category.id,
          category.name,
          category.type.name,
          category.colorHex,
        ]);
      }
      for (final transaction in backup.transactions) {
        db.execute(
          'insert into transactions values (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            transaction.id,
            transaction.walletId,
            transaction.toWalletId,
            transaction.categoryId,
            transaction.type.name,
            transaction.amount,
            transaction.date.toIso8601String(),
            transaction.note,
            transaction.isRecurring ? 1 : 0,
          ],
        );
      }
      for (final budget in backup.budgets) {
        db.execute('insert into budgets values (?, ?, ?, ?)', [
          budget.id,
          budget.categoryId,
          budget.month.toIso8601String(),
          budget.limitAmount,
        ]);
      }
      for (final goal in backup.goals) {
        db.execute('insert into saving_goals values (?, ?, ?, ?, ?)', [
          goal.id,
          goal.name,
          goal.targetAmount,
          goal.savedAmount,
          goal.deadline.toIso8601String(),
        ]);
      }
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }
}