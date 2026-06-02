import 'package:sqlite3/sqlite3.dart';

import '../core/finance_models.dart';
import 'local_store_core.dart';
import 'local_store_sync_operations.dart';
import 'local_store_validation.dart';

class TransactionOperations {
  TransactionOperations(
    this._core,
    this._sync,
    this._validation,
  );

  final FinanceStoreCore _core;
  final SyncOperations _sync;
  final ValidationOperations _validation;

  Future<void> addTransaction({
    required TransactionType type,
    required String walletId,
    required String categoryId,
    required int amount,
    required DateTime date,
    required String note,
    bool isRecurring = false,
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }
    final db = await _core.open();
    _validation.assertWalletExists(db, walletId);
    _validation.assertCategoryExists(db, categoryId, expectedType: type);
    final id = _core.newId('txn');
    final payload = _sync.transactionPayload(
      walletId: walletId,
      toWalletId: null,
      categoryId: categoryId,
      type: type,
      amount: amount,
      date: date,
      note: note,
      isRecurring: isRecurring,
    );
    db.execute('begin immediate');
    try {
      _insertTransaction(db, id, walletId, categoryId, type, amount, date, note, isRecurring, null);
      _sync.markLocalCreate(db, entityType: SyncOperations.entityTransaction, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entityTransaction,
        localId: id,
        operation: SyncOperations.operationCreate,
        payload: payload,
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

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
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }
    final db = await _core.open();
    _validation.assertWalletExists(db, walletId);
    _validation.assertCategoryExists(db, categoryId, expectedType: type);
    final payload = _sync.transactionPayload(
      walletId: walletId,
      toWalletId: null,
      categoryId: categoryId,
      type: type,
      amount: amount,
      date: date,
      note: note,
      isRecurring: isRecurring,
    );
    db.execute('begin immediate');
    try {
      _updateTransactionRow(db, id, walletId, categoryId, type, amount, date, note, isRecurring);
      _sync.markLocalUpdate(db, entityType: SyncOperations.entityTransaction, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entityTransaction,
        localId: id,
        operation: SyncOperations.operationUpdate,
        payload: payload,
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _core.open();
    db.execute('begin immediate');
    try {
      db.execute('delete from transactions where id = ?', [id]);
      _sync.markLocalDelete(db, entityType: SyncOperations.entityTransaction, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entityTransaction,
        localId: id,
        operation: SyncOperations.operationDelete,
        payload: const {},
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> transfer({
    required String fromWalletId,
    required String toWalletId,
    required int amount,
    required DateTime date,
    required String note,
  }) async {
    if (fromWalletId == toWalletId) {
      throw ArgumentError('Wallets must be different');
    }
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }
    final db = await _core.open();
    _validation.assertWalletExists(db, fromWalletId);
    _validation.assertWalletExists(db, toWalletId);
    _validation.assertCategoryExists(
      db, 'transfer', expectedType: TransactionType.transfer,
    );
    final localId = _core.newId('trf');
    db.execute('begin immediate');
    try {
      _insertTransaction(
        db, localId, fromWalletId, 'transfer', TransactionType.transfer,
        amount, date, note, false, toWalletId,
      );
      _sync.markLocalCreate(
        db, entityType: SyncOperations.entityTransaction, localId: localId,
      );
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entityTransaction,
        localId: localId,
        operation: SyncOperations.operationCreate,
        payload: _sync.transactionPayload(
          walletId: fromWalletId,
          toWalletId: toWalletId,
          categoryId: 'transfer',
          type: TransactionType.transfer,
          amount: amount,
          date: date,
          note: note,
          isRecurring: false,
        ),
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  void _insertTransaction(
    Database db, String id, String walletId, String categoryId,
    TransactionType type, int amount, DateTime date, String note,
    bool isRecurring, String? toWalletId,
  ) {
    db.execute(
      'insert into transactions values (?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [
        id,
        walletId,
        toWalletId,
        categoryId,
        type.name,
        amount,
        date.toIso8601String(),
        note,
        isRecurring ? 1 : 0,
      ],
    );
  }

  void _updateTransactionRow(
    Database db, String id, String walletId, String categoryId,
    TransactionType type, int amount, DateTime date, String note,
    bool isRecurring,
  ) {
    db.execute(
      'update transactions set wallet_id = ?, to_wallet_id = null, category_id = ?, type = ?, amount = ?, date = ?, note = ?, is_recurring = ? where id = ?',
      [walletId, categoryId, type.name, amount, date.toIso8601String(), note, isRecurring ? 1 : 0, id],
    );
  }
}
