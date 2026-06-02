import '../core/finance_models.dart';
import 'local_store_core.dart';
import 'local_store_sync_operations.dart';
import 'local_store_validation.dart';

class BudgetOperations {
  BudgetOperations(
    this._core,
    this._sync,
    this._validation,
  );

  final FinanceStoreCore _core;
  final SyncOperations _sync;
  final ValidationOperations _validation;

  Future<void> upsertBudget({
    required String categoryId,
    required DateTime month,
    required int limitAmount,
  }) async {
    if (limitAmount <= 0) {
      throw ArgumentError.value(limitAmount, 'limitAmount', 'Limit must be positive');
    }
    final db = await _core.open();
    _validation.assertBudgetMonthFirstDay(month);
    _validation.assertCategoryExists(db, categoryId, expectedType: TransactionType.expense);
    final monthKey = DateTime(month.year, month.month).toIso8601String();
    final existing = db.select(
      'select id from budgets where category_id = ? and month = ? limit 1',
      [categoryId, monthKey],
    );
    if (existing.isEmpty) {
      final id = _core.newId('budget');
      db.execute('begin immediate');
      try {
        db.execute('insert into budgets values (?, ?, ?, ?)', [id, categoryId, monthKey, limitAmount]);
        _sync.markLocalCreate(db, entityType: SyncOperations.entityBudget, localId: id);
        _sync.enqueueLocalMutation(
          db,
          entityType: SyncOperations.entityBudget,
          localId: id,
          operation: SyncOperations.operationCreate,
          payload: _sync.budgetPayload(
            categoryId: categoryId,
            month: DateTime(month.year, month.month),
            limitAmount: limitAmount,
          ),
        );
        db.execute('commit');
      } on Object {
        db.execute('rollback');
        rethrow;
      }
      return;
    }
    final id = existing.first['id'] as String;
    db.execute('begin immediate');
    try {
      db.execute('update budgets set limit_amount = ? where id = ?', [limitAmount, id]);
      _sync.markLocalUpdate(db, entityType: SyncOperations.entityBudget, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entityBudget,
        localId: id,
        operation: SyncOperations.operationUpdate,
        payload: _sync.budgetPayload(
          categoryId: categoryId,
          month: DateTime(month.year, month.month),
          limitAmount: limitAmount,
        ),
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> updateBudget({
    required String id,
    required String categoryId,
    required DateTime month,
    required int limitAmount,
  }) async {
    if (limitAmount <= 0) {
      throw ArgumentError.value(limitAmount, 'limitAmount', 'Limit must be positive');
    }
    final db = await _core.open();
    _validation.assertBudgetMonthFirstDay(month);
    _validation.assertCategoryExists(db, categoryId, expectedType: TransactionType.expense);
    final monthKey = DateTime(month.year, month.month).toIso8601String();
    db.execute('begin immediate');
    try {
      db.execute(
        'update budgets set category_id = ?, month = ?, limit_amount = ? where id = ?',
        [categoryId, monthKey, limitAmount, id],
      );
      _sync.markLocalUpdate(db, entityType: SyncOperations.entityBudget, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entityBudget,
        localId: id,
        operation: SyncOperations.operationUpdate,
        payload: _sync.budgetPayload(
          categoryId: categoryId,
          month: DateTime(month.year, month.month),
          limitAmount: limitAmount,
        ),
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> deleteBudget(String id) async {
    final db = await _core.open();
    db.execute('begin immediate');
    try {
      db.execute('delete from budgets where id = ?', [id]);
      _sync.markLocalDelete(db, entityType: SyncOperations.entityBudget, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entityBudget,
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
}
