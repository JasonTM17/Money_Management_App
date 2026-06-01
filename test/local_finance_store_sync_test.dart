import 'dart:convert';
import 'dart:io';

import 'package:cashflow_manager/core/sync_models.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/data/local_finance_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('seeds starter text with valid Unicode', () async {
    final store = LocalFinanceStore(
      databasePath: await _temporaryDatabasePath(),
    );
    final state = await store.load();

    expect(
      state.wallets.singleWhere((wallet) => wallet.id == 'cash').name,
      'Tiền mặt',
    );
    expect(
      state.wallets.singleWhere((wallet) => wallet.id == 'bank').name,
      'Ngân hàng',
    );
    expect(
      state.categories.singleWhere((category) => category.id == 'food').name,
      'Ăn uống',
    );
    expect(
      state.transactions.any(
        (transaction) => transaction.note == 'Lương tháng này',
      ),
      isTrue,
    );
    expect(state.goals.single.name, 'Quỹ khẩn cấp');
  });

  test('repairs mojibake starter text during load', () async {
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
      ..execute('insert into wallets values (?, ?, ?, ?)', [
        'cash',
        _doubleMojibake('Tiền mặt'),
        'cash',
        2500000,
      ])
      ..execute('insert into wallets values (?, ?, ?, ?)', [
        'bank',
        _mojibake('Ngân hàng'),
        'bank',
        12000000,
      ])
      ..execute('insert into wallets values (?, ?, ?, ?)', [
        'ewallet',
        _mojibake('Ví điện tử'),
        'eWallet',
        1500000,
      ])
      ..execute('insert into categories values (?, ?, ?, ?)', [
        'salary',
        _mojibake('Lương'),
        'income',
        4283215696,
      ])
      ..execute('insert into categories values (?, ?, ?, ?)', [
        'food',
        _doubleMojibake('Ăn uống'),
        'expense',
        4294198070,
      ])
      ..execute('insert into categories values (?, ?, ?, ?)', [
        'transfer',
        _mojibake('Chuyển ví'),
        'transfer',
        4288585374,
      ])
      ..execute('insert into transactions values (?, ?, null, ?, ?, ?, ?, ?)', [
        'txn-salary',
        'bank',
        'salary',
        'income',
        18000000,
        '2026-06-01T00:00:00.000',
        _doubleMojibake('Lương tháng này'),
      ])
      ..execute('insert into saving_goals values (?, ?, ?, ?, ?)', [
        'goal-emergency',
        _mojibake('Quỹ khẩn cấp'),
        50000000,
        12500000,
        '2026-12-01T00:00:00.000',
      ])
      ..close();

    final state = await LocalFinanceStore(databasePath: dbPath).load();

    expect(
      state.wallets.singleWhere((wallet) => wallet.id == 'cash').name,
      'Tiền mặt',
    );
    expect(
      state.wallets.singleWhere((wallet) => wallet.id == 'bank').name,
      'Ngân hàng',
    );
    expect(
      state.categories.singleWhere((category) => category.id == 'food').name,
      'Ăn uống',
    );
    expect(state.transactions.single.note, 'Lương tháng này');
    expect(state.goals.single.name, 'Quỹ khẩn cấp');
  });
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

  test(
    'local validation rejects category type mismatches before enqueue',
    () async {
      final store = LocalFinanceStore(
        databasePath: await _temporaryDatabasePath(),
      );
      await store.load();

      await expectLater(
        store.addTransaction(
          type: TransactionType.income,
          walletId: 'cash',
          categoryId: 'food',
          amount: 1000,
          date: DateTime(2026, 6),
          note: 'wrong category',
        ),
        throwsArgumentError,
      );

      final syncStatus = await store.loadSyncStatus();
      expect(syncStatus.pendingCount, 0);
    },
  );

  test(
    'local validation rejects budgets outside the first day of month',
    () async {
      final store = LocalFinanceStore(
        databasePath: await _temporaryDatabasePath(),
      );
      await store.load();

      await expectLater(
        store.upsertBudget(
          categoryId: 'food',
          month: DateTime(2026, 6, 2),
          limitAmount: 1000000,
        ),
        throwsArgumentError,
      );

      final syncStatus = await store.loadSyncStatus();
      expect(syncStatus.pendingCount, 0);
    },
  );

  test('local validation rejects transfers to missing wallets', () async {
    final store = LocalFinanceStore(
      databasePath: await _temporaryDatabasePath(),
    );
    await store.load();

    await expectLater(
      store.transfer(
        fromWalletId: 'cash',
        toWalletId: 'missing-wallet',
        amount: 1000,
        date: DateTime(2026, 6),
        note: 'missing target',
      ),
      throwsArgumentError,
    );

    final syncStatus = await store.loadSyncStatus();
    expect(syncStatus.pendingCount, 0);
  });

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

String _mojibake(String value) => _decodeWindows1252(utf8.encode(value));

String _doubleMojibake(String value) => _mojibake(_mojibake(value));

String _decodeWindows1252(List<int> bytes) =>
    String.fromCharCodes(bytes.map((byte) => _windows1252CodePoint(byte)));

int _windows1252CodePoint(int byte) => switch (byte) {
  0x80 => 0x20AC,
  0x82 => 0x201A,
  0x83 => 0x0192,
  0x84 => 0x201E,
  0x85 => 0x2026,
  0x86 => 0x2020,
  0x87 => 0x2021,
  0x88 => 0x02C6,
  0x89 => 0x2030,
  0x8A => 0x0160,
  0x8B => 0x2039,
  0x8C => 0x0152,
  0x8E => 0x017D,
  0x91 => 0x2018,
  0x92 => 0x2019,
  0x93 => 0x201C,
  0x94 => 0x201D,
  0x95 => 0x2022,
  0x96 => 0x2013,
  0x97 => 0x2014,
  0x98 => 0x02DC,
  0x99 => 0x2122,
  0x9A => 0x0161,
  0x9B => 0x203A,
  0x9C => 0x0153,
  0x9E => 0x017E,
  0x9F => 0x0178,
  _ => byte,
};
