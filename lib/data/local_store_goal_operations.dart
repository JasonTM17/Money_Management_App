import 'local_store_core.dart';
import 'local_store_sync_operations.dart';
import 'local_store_validation.dart';

class GoalOperations {
  GoalOperations(
    this._core,
    this._sync,
    this._validation,
  );

  final FinanceStoreCore _core;
  final SyncOperations _sync;
  final ValidationOperations _validation;

  Future<void> saveGoal({
    String? id,
    required String name,
    required int targetAmount,
    required int savedAmount,
    required DateTime deadline,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Goal name is required');
    }
    _validation.assertSavingGoalAmounts(
      targetAmount: targetAmount,
      savedAmount: savedAmount,
    );
    final db = await _core.open();
    if (id == null) {
      final localId = _core.newId('goal');
      db.execute('begin immediate');
      try {
        db.execute('insert into saving_goals values (?, ?, ?, ?, ?)', [
          localId, name.trim(), targetAmount, savedAmount, deadline.toIso8601String(),
        ]);
        _sync.markLocalCreate(db, entityType: SyncOperations.entitySavingGoal, localId: localId);
        _sync.enqueueLocalMutation(
          db,
          entityType: SyncOperations.entitySavingGoal,
          localId: localId,
          operation: SyncOperations.operationCreate,
          payload: _sync.savingGoalPayload(
            name: name.trim(), targetAmount: targetAmount,
            savedAmount: savedAmount, deadline: deadline,
          ),
        );
        db.execute('commit');
      } on Object {
        db.execute('rollback');
        rethrow;
      }
      return;
    }
    db.execute('begin immediate');
    try {
      db.execute(
        'update saving_goals set name = ?, target_amount = ?, saved_amount = ?, deadline = ? where id = ?',
        [name.trim(), targetAmount, savedAmount, deadline.toIso8601String(), id],
      );
      _sync.markLocalUpdate(db, entityType: SyncOperations.entitySavingGoal, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entitySavingGoal,
        localId: id,
        operation: SyncOperations.operationUpdate,
        payload: _sync.savingGoalPayload(
          name: name.trim(), targetAmount: targetAmount,
          savedAmount: savedAmount, deadline: deadline,
        ),
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    final db = await _core.open();
    db.execute('begin immediate');
    try {
      db.execute('delete from saving_goals where id = ?', [id]);
      _sync.markLocalDelete(db, entityType: SyncOperations.entitySavingGoal, localId: id);
      _sync.enqueueLocalMutation(
        db,
        entityType: SyncOperations.entitySavingGoal,
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
