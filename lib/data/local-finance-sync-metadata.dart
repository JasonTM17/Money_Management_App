part of 'local_finance_store.dart';

const _syncEntityWallet = 'wallet';
const _syncEntityCategory = 'category';
const _syncEntityTransaction = 'transaction';
const _syncEntityBudget = 'budget';
const _syncEntitySavingGoal = 'savingGoal';
const _syncOperationCreate = 'create';
const _syncOperationUpdate = 'update';
const _syncOperationDelete = 'delete';
const _syncOutboxPending = 'pending';
const _syncOutboxApplied = 'applied';
const _syncOutboxConflict = 'conflict';

class LocalSyncStatus {
  const LocalSyncStatus({
    required this.pendingCount,
    required this.readyCount,
    required this.conflictCount,
    this.cursor,
    this.lastSyncedAt,
  });

  final int pendingCount;
  final int readyCount;
  final int conflictCount;
  final String? cursor;
  final DateTime? lastSyncedAt;

  bool get hasPendingWork => pendingCount > 0;
  bool get hasConflicts => conflictCount > 0;
}

extension LocalFinanceStoreSync on LocalFinanceStore {
  Future<LocalSyncStatus> loadSyncStatus() async {
    final db = await _open();
    final pendingRows = db.select(
      "select * from sync_outbox where status = ? order by created_at",
      [_syncOutboxPending],
    );
    final readyCount = pendingRows
        .where((row) => _remoteMutationFromRow(db, row) != null)
        .length;
    final conflictCount =
        db
                .select(
                  'select count(*) c from sync_conflicts where resolved_at is null',
                )
                .first['c']
            as int;
    final cursor = _readSyncState(db, 'cursor');
    final lastSyncedAt = _readSyncState(db, 'last_synced_at');
    return LocalSyncStatus(
      pendingCount: pendingRows.length,
      readyCount: readyCount,
      conflictCount: conflictCount,
      cursor: cursor,
      lastSyncedAt: lastSyncedAt == null ? null : DateTime.parse(lastSyncedAt),
    );
  }

  Future<List<RemoteSyncMutation>> pendingRemoteMutations({
    int limit = 100,
  }) async {
    final db = await _open();
    final rows = db.select(
      "select * from sync_outbox where status = ? order by created_at limit ?",
      [_syncOutboxPending, limit],
    );
    return [for (final row in rows) ?_remoteMutationFromRow(db, row)];
  }

  Future<void> saveSyncServerMapping({
    required String entityType,
    required String localId,
    required String serverId,
    int revision = 0,
  }) async {
    final db = await _open();
    _upsertSyncMetadata(
      db,
      entityType: entityType,
      localId: localId,
      serverId: serverId,
      revision: revision,
    );
  }

  Future<void> markSyncPushResult(RemoteSyncPushResponse response) async {
    final db = await _open();
    db.execute('begin immediate');
    try {
      for (final applied in response.applied) {
        final mutationId = applied['clientMutationId'];
        if (mutationId is! String) continue;
        final record = applied['record'];
        final outbox = db.select(
          'select * from sync_outbox where id = ? limit 1',
          [mutationId],
        );
        if (outbox.isNotEmpty && record is Map<String, Object?>) {
          final serverId = record['id'];
          final revision = record['revision'];
          if (serverId is String && revision is int) {
            _upsertSyncMetadata(
              db,
              entityType: outbox.first['entity_type'] as String,
              localId: outbox.first['local_id'] as String,
              serverId: serverId,
              revision: revision,
            );
          }
        }
        db.execute(
          'update sync_outbox set status = ?, updated_at = ? where id = ?',
          [_syncOutboxApplied, _nowIso(), mutationId],
        );
      }
      for (final conflict in response.conflicts) {
        _recordSyncConflict(db, conflict);
      }
      _writeSyncState(db, 'last_synced_at', _nowIso());
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> saveSyncCursor(String cursor) async {
    final db = await _open();
    _writeSyncState(db, 'cursor', cursor);
    _writeSyncState(db, 'last_synced_at', _nowIso());
  }
}

void _migrateSyncTables(Database db) {
  db.execute(
    'create table if not exists sync_metadata(entity_type text not null, local_id text not null, server_id text, revision integer not null default 0, deleted_at text, updated_at text not null, primary key(entity_type, local_id))',
  );
  db.execute(
    'create unique index if not exists idx_sync_metadata_server on sync_metadata(entity_type, server_id) where server_id is not null',
  );
  db.execute(
    'create table if not exists sync_outbox(id text primary key, entity_type text not null, local_id text not null, server_id text, operation text not null, base_revision integer, payload_json text not null, status text not null, created_at text not null, updated_at text not null)',
  );
  db.execute(
    'create index if not exists idx_sync_outbox_status_created on sync_outbox(status, created_at)',
  );
  db.execute(
    'create table if not exists sync_state(key text primary key, value text not null)',
  );
  db.execute(
    'create table if not exists sync_conflicts(id text primary key, client_mutation_id text not null, entity_type text not null, local_id text, server_id text, server_revision integer, local_payload_json text not null, server_payload_json text not null, created_at text not null, resolved_at text)',
  );
  db.execute(
    'create index if not exists idx_sync_conflicts_open on sync_conflicts(resolved_at, created_at)',
  );
  db.execute(
    'create table if not exists receipt_metadata(id text primary key, transaction_id text, image_path text not null, merchant text, amount integer, date text, raw_text text not null, confidence real not null, created_at text not null)',
  );
}

void _ensureSyncMetadataForExistingRows(Database db) {
  final now = _nowIso();
  for (final row in db.select('select id from wallets')) {
    _insertMetadataIfMissing(db, _syncEntityWallet, row['id'] as String, now);
  }
  for (final row in db.select('select id from categories')) {
    _insertMetadataIfMissing(db, _syncEntityCategory, row['id'] as String, now);
  }
  for (final row in db.select('select id from transactions')) {
    _insertMetadataIfMissing(
      db,
      _syncEntityTransaction,
      row['id'] as String,
      now,
    );
  }
  for (final row in db.select('select id from budgets')) {
    _insertMetadataIfMissing(db, _syncEntityBudget, row['id'] as String, now);
  }
  for (final row in db.select('select id from saving_goals')) {
    _insertMetadataIfMissing(
      db,
      _syncEntitySavingGoal,
      row['id'] as String,
      now,
    );
  }
}

void _deleteAllSyncState(Database db) {
  db.execute('delete from sync_conflicts');
  db.execute('delete from sync_outbox');
  db.execute('delete from sync_state');
  db.execute('delete from sync_metadata');
  db.execute('delete from receipt_metadata');
}

void _markLocalCreate(
  Database db, {
  required String entityType,
  required String localId,
}) {
  _upsertSyncMetadata(
    db,
    entityType: entityType,
    localId: localId,
    serverId: _uuidV4(),
    revision: 0,
  );
}

void _markLocalUpdate(
  Database db, {
  required String entityType,
  required String localId,
}) {
  _upsertSyncMetadata(db, entityType: entityType, localId: localId);
}

void _markLocalDelete(
  Database db, {
  required String entityType,
  required String localId,
}) {
  _upsertSyncMetadata(
    db,
    entityType: entityType,
    localId: localId,
    deletedAt: _nowIso(),
  );
}

void _enqueueLocalMutation(
  Database db, {
  required String entityType,
  required String localId,
  required String operation,
  required Map<String, Object?> payload,
}) {
  final metadata = _metadataForLocal(db, entityType, localId);
  final now = _nowIso();
  db.execute(
    'insert into sync_outbox(id, entity_type, local_id, server_id, operation, base_revision, payload_json, status, created_at, updated_at) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      _uuidV4(),
      entityType,
      localId,
      metadata?['server_id'],
      operation,
      operation == _syncOperationCreate ? null : metadata?['revision'],
      jsonEncode(payload),
      _syncOutboxPending,
      now,
      now,
    ],
  );
}

RemoteSyncMutation? _remoteMutationFromRow(Database db, Row row) {
  final entityType = row['entity_type'] as String;
  final serverId = row['server_id'] as String?;
  if (serverId == null) return null;
  final payload = jsonDecode(row['payload_json'] as String);
  if (payload is! Map<String, Object?>) return null;
  final remotePayload = _remotePayload(db, entityType, payload);
  if (remotePayload == null) return null;
  return RemoteSyncMutation(
    clientMutationId: row['id'] as String,
    entityType: entityType,
    entityId: serverId,
    operation: row['operation'] as String,
    baseRevision: row['base_revision'] as int?,
    payload: remotePayload,
  );
}

Map<String, Object?>? _remotePayload(
  Database db,
  String entityType,
  Map<String, Object?> payload,
) {
  if (payload.isEmpty) return payload;
  final next = Map<String, Object?>.of(payload);
  switch (entityType) {
    case _syncEntityTransaction:
      if (!_replaceLocalReference(db, next, 'walletId', _syncEntityWallet)) {
        return null;
      }
      if (!_replaceLocalReference(
        db,
        next,
        'categoryId',
        _syncEntityCategory,
      )) {
        return null;
      }
      if (next['toWalletId'] != null &&
          !_replaceLocalReference(db, next, 'toWalletId', _syncEntityWallet)) {
        return null;
      }
      break;
    case _syncEntityBudget:
      if (!_replaceLocalReference(
        db,
        next,
        'categoryId',
        _syncEntityCategory,
      )) {
        return null;
      }
      break;
  }
  return next;
}

bool _replaceLocalReference(
  Database db,
  Map<String, Object?> payload,
  String key,
  String entityType,
) {
  final localId = payload[key];
  if (localId is! String) return false;
  final metadata = _metadataForLocal(db, entityType, localId);
  final serverId = metadata?['server_id'];
  if (serverId is! String) return false;
  payload[key] = serverId;
  return true;
}

Map<String, Object?> _transactionPayload({
  required String walletId,
  required String? toWalletId,
  required String categoryId,
  required TransactionType type,
  required int amount,
  required DateTime date,
  required String note,
  required bool isRecurring,
}) => {
  'walletId': walletId,
  'toWalletId': toWalletId,
  'categoryId': categoryId,
  'type': type.name,
  'amount': amount,
  'date': date.toIso8601String(),
  'note': note,
  'isRecurring': isRecurring,
};

Map<String, Object?> _budgetPayload({
  required String categoryId,
  required DateTime month,
  required int limitAmount,
}) => {
  'categoryId': categoryId,
  'month': _dateOnly(month),
  'limitAmount': limitAmount,
};

Map<String, Object?> _savingGoalPayload({
  required String name,
  required int targetAmount,
  required int savedAmount,
  required DateTime deadline,
}) => {
  'name': name,
  'targetAmount': targetAmount,
  'savedAmount': savedAmount,
  'deadline': _dateOnly(deadline),
};

void _recordSyncConflict(Database db, Map<String, Object?> conflict) {
  final mutationId = conflict['clientMutationId'];
  if (mutationId is! String) return;
  final outbox = db.select('select * from sync_outbox where id = ? limit 1', [
    mutationId,
  ]);
  final localPayload = outbox.isEmpty
      ? const <String, Object?>{}
      : jsonDecode(outbox.first['payload_json'] as String);
  final server = conflict['server'];
  final serverRevision =
      server is Map<String, Object?> && server['revision'] is int
      ? server['revision'] as int
      : null;
  final outboxRow = outbox.isEmpty ? null : outbox.first;
  final now = _nowIso();
  db.execute(
    'insert or replace into sync_conflicts(id, client_mutation_id, entity_type, local_id, server_id, server_revision, local_payload_json, server_payload_json, created_at, resolved_at) values (?, ?, ?, ?, ?, ?, ?, ?, ?, null)',
    [
      _uuidV4(),
      mutationId,
      conflict['entityType'] is String
          ? conflict['entityType']
          : outboxRow?['entity_type'],
      outboxRow?['local_id'],
      conflict['entityId'] is String ? conflict['entityId'] : null,
      serverRevision,
      jsonEncode(localPayload),
      jsonEncode(server ?? const <String, Object?>{}),
      now,
    ],
  );
  db.execute('update sync_outbox set status = ?, updated_at = ? where id = ?', [
    _syncOutboxConflict,
    now,
    mutationId,
  ]);
}

void _insertMetadataIfMissing(
  Database db,
  String entityType,
  String localId,
  String now,
) {
  db.execute(
    'insert or ignore into sync_metadata(entity_type, local_id, revision, updated_at) values (?, ?, 0, ?)',
    [entityType, localId, now],
  );
}

void _upsertSyncMetadata(
  Database db, {
  required String entityType,
  required String localId,
  String? serverId,
  int? revision,
  String? deletedAt,
}) {
  final current = _metadataForLocal(db, entityType, localId);
  final now = _nowIso();
  if (current == null) {
    db.execute(
      'insert into sync_metadata(entity_type, local_id, server_id, revision, deleted_at, updated_at) values (?, ?, ?, ?, ?, ?)',
      [entityType, localId, serverId, revision ?? 0, deletedAt, now],
    );
    return;
  }
  db.execute(
    'update sync_metadata set server_id = ?, revision = ?, deleted_at = ?, updated_at = ? where entity_type = ? and local_id = ?',
    [
      serverId ?? current['server_id'],
      revision ?? current['revision'],
      deletedAt ?? current['deleted_at'],
      now,
      entityType,
      localId,
    ],
  );
}

Row? _metadataForLocal(Database db, String entityType, String localId) {
  final rows = db.select(
    'select * from sync_metadata where entity_type = ? and local_id = ? limit 1',
    [entityType, localId],
  );
  return rows.isEmpty ? null : rows.first;
}

String? _readSyncState(Database db, String key) {
  final rows = db.select('select value from sync_state where key = ? limit 1', [
    key,
  ]);
  return rows.isEmpty ? null : rows.first['value'] as String;
}

void _writeSyncState(Database db, String key, String value) {
  db.execute(
    'insert into sync_state(key, value) values (?, ?) on conflict(key) do update set value = excluded.value',
    [key, value],
  );
}

String _uuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  String hex(int value) => value.toRadixString(16).padLeft(2, '0');
  final chars = bytes.map(hex).join();
  return '${chars.substring(0, 8)}-${chars.substring(8, 12)}-'
      '${chars.substring(12, 16)}-${chars.substring(16, 20)}-'
      '${chars.substring(20)}';
}

String _dateOnly(DateTime date) => DateTime(
  date.year,
  date.month,
  date.day,
).toIso8601String().split('T').first;

String _nowIso() => DateTime.now().toUtc().toIso8601String();
