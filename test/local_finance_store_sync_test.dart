import 'dart:io';

import 'package:cashflow_manager/core/sync_models.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/data/local_finance_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('sync migration preserves legacy local finance rows', () async {
    final dbPath = await _temporaryDatabasePath();
    final legacyDb = sqlite3.open(dbPath);
    legacyDb
      ..execute(
        'create table wallets(id text primary key, name text not null, type text not null, initial_balance integer not null)',
      )
      ..execute(
        'create table categories(id text primary key, name text not null, type text not null, color_hex integer not null)',
      )
      ..execute(
        'create table transactions(id text primary key, wallet_id text not null, to_wallet_id text, category_id text not null, type text not null, amount integer not null, date text not null, note text not null)',
      )
      ..execute(
        'create table budgets(id text primary key, category_id text not null, month text not null, limit_amount integer not null)',
      )
      ..execute(
        'create table saving_goals(id text primary key, name text not null, target_amount integer not null, saved_amount integer not null, deadline text not null)',
      )
      ..execute("insert into wallets values ('cash', 'Cash', 'cash', 1000)")
      ..execute(
        "insert into categories values ('food', 'Food', 'expense', 4294198070)",
      )
      ..execute(
        "insert into transactions values ('txn-legacy', 'cash', null, 'food', 'expense', 500, '2026-06-01T00:00:00.000', 'Coffee')",
      )
      ..close();

    final store = LocalFinanceStore(databasePath: dbPath);
    final state = await store.load();
    final syncStatus = await store.loadSyncStatus();

    expect(state.wallets.single.id, 'cash');
    expect(state.transactions.single.isRecurring, isFalse);
    expect(syncStatus.pendingCount, 0);
    expect(syncStatus.conflictCount, 0);
  });

  test(
    'local mutations stay queued until referenced ids have server mappings',
    () async {
      final store = LocalFinanceStore(
        databasePath: await _temporaryDatabasePath(),
      );
      await store.load();

      await store.addTransaction(
        type: TransactionType.expense,
        walletId: 'cash',
        categoryId: 'food',
        amount: 120000,
        date: DateTime(2026, 6),
        note: 'Lunch',
      );

      var syncStatus = await store.loadSyncStatus();
      expect(syncStatus.pendingCount, 1);
      expect(syncStatus.readyCount, 0);
      expect(await store.pendingRemoteMutations(), isEmpty);

      await store.saveSyncServerMapping(
        entityType: 'wallet',
        localId: 'cash',
        serverId: '10000000-0000-4000-8000-000000000001',
      );
      await store.saveSyncServerMapping(
        entityType: 'category',
        localId: 'food',
        serverId: '10000000-0000-4000-8000-000000000002',
      );

      final mutations = await store.pendingRemoteMutations();
      syncStatus = await store.loadSyncStatus();

      expect(syncStatus.readyCount, 1);
      expect(mutations.single.operation, 'create');
      expect(mutations.single.entityId, matches(_uuidPattern));
      expect(
        mutations.single.payload['walletId'],
        '10000000-0000-4000-8000-000000000001',
      );
      expect(
        mutations.single.payload['categoryId'],
        '10000000-0000-4000-8000-000000000002',
      );
    },
  );

  test('sync conflicts are visible and keep local draft data', () async {
    final store = LocalFinanceStore(
      databasePath: await _temporaryDatabasePath(),
    );
    await store.load();
    await store.saveSyncServerMapping(
      entityType: 'wallet',
      localId: 'cash',
      serverId: '10000000-0000-4000-8000-000000000001',
    );
    await store.saveSyncServerMapping(
      entityType: 'category',
      localId: 'food',
      serverId: '10000000-0000-4000-8000-000000000002',
    );
    await store.addTransaction(
      type: TransactionType.expense,
      walletId: 'cash',
      categoryId: 'food',
      amount: 99000,
      date: DateTime(2026, 6),
      note: 'Keep local draft',
    );
    final mutation = (await store.pendingRemoteMutations()).single;

    await store.markSyncPushResult(
      RemoteSyncPushResponse(
        applied: const [],
        conflicts: [
          {
            'clientMutationId': mutation.clientMutationId,
            'entityType': mutation.entityType,
            'entityId': mutation.entityId,
            'server': {'id': mutation.entityId, 'revision': 2},
          },
        ],
      ),
    );

    final state = await store.load();
    final syncStatus = await store.loadSyncStatus();

    expect(syncStatus.conflictCount, 1);
    expect(syncStatus.pendingCount, 0);
    expect(
      state.transactions.any(
        (transaction) => transaction.note == 'Keep local draft',
      ),
      isTrue,
    );
  });
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
);

Future<String> _temporaryDatabasePath() async {
  final directory = await Directory.systemTemp.createTemp(
    'cashflow-sync-test-',
  );
  return '${directory.path}${Platform.pathSeparator}cashflow.sqlite';
}
