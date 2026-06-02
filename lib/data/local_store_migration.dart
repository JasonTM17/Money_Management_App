import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import 'local_store_core.dart';

class MigrationOperations {
  MigrationOperations(this._core);
  final FinanceStoreCore _core;

  void runMigration(Database db) {
    db.execute('pragma foreign_keys = on');
    db.execute(
      'create table if not exists wallets(id text primary key, name text not null, type text not null, initial_balance integer not null)',
    );
    db.execute(
      'create table if not exists categories(id text primary key, name text not null, type text not null, color_hex integer not null)',
    );
    db.execute(
      'create table if not exists transactions(id text primary key, wallet_id text not null, to_wallet_id text, category_id text not null, type text not null, amount integer not null, date text not null, note text not null, is_recurring integer not null default 0)',
    );
    db.execute(
      'create table if not exists budgets(id text primary key, category_id text not null, month text not null, limit_amount integer not null)',
    );
    db.execute(
      'create table if not exists saving_goals(id text primary key, name text not null, target_amount integer not null, saved_amount integer not null, deadline text not null)',
    );
    _migrateSyncTables(db);
    _ensureRecurringColumn(db);
    db.execute(
      'create index if not exists idx_transactions_date on transactions(date desc)',
    );
    db.execute(
      'create index if not exists idx_transactions_wallet on transactions(wallet_id)',
    );
    db.execute(
      'create index if not exists idx_transactions_category_date on transactions(category_id, date)',
    );
    cleanInvalidRows(db);
    _ensureSyncMetadataForExistingRows(db);
    db.execute(
      'create unique index if not exists idx_budgets_category_month on budgets(category_id, month)',
    );
  }

  void _ensureRecurringColumn(Database db) {
    final columns = db
        .select('pragma table_info(transactions)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!columns.contains('is_recurring')) {
      db.execute(
        'alter table transactions add column is_recurring integer not null default 0',
      );
    }
  }

  void cleanInvalidRows(Database db) {
    db.execute('delete from budgets where limit_amount <= 0');
    db.execute(
      'delete from budgets where category_id not in (select id from categories)',
    );
    db.execute(
      'delete from budgets where rowid not in (select min(rowid) from budgets group by category_id, month)',
    );
    db.execute('delete from saving_goals where target_amount <= 0');
    db.execute(
      'delete from saving_goals where saved_amount < 0 or saved_amount > target_amount',
    );
    db.execute('delete from transactions where amount <= 0');
    db.execute(
      'delete from transactions where wallet_id not in (select id from wallets)',
    );
    db.execute(
      'delete from transactions where category_id not in (select id from categories)',
    );
    db.execute(
      "delete from transactions where type = 'transfer' and (to_wallet_id is null or to_wallet_id not in (select id from wallets) or to_wallet_id = wallet_id)",
    );
  }

  void deleteAllData(Database db) {
    db.execute('delete from transactions');
    db.execute('delete from budgets');
    db.execute('delete from saving_goals');
    db.execute('delete from categories');
    db.execute('delete from wallets');
  }

  void seed(Database db) {
    final count = db.select('select count(*) c from wallets').first['c'] as int;
    if (count > 0) return;
    db.execute(
      "insert into wallets values ('cash', 'Tiền mặt', 'cash', 2500000), ('bank', 'Ngân hàng', 'bank', 12000000), ('ewallet', 'Ví điện tử', 'eWallet', 1500000)",
    );
    db.execute(
      "insert into categories values ('salary', 'Lương', 'income', 4283215696), ('food', 'Ăn uống', 'expense', 4294198070), ('transport', 'Di chuyển', 'expense', 4280391411), ('bill', 'Hóa đơn', 'expense', 4294944000), ('saving', 'Tiết kiệm', 'expense', 4283215696), ('transfer', 'Chuyển ví', 'transfer', 4288585374)",
    );
    final now = DateTime.now();
    db.execute(
      'insert into transactions values (?, ?, null, ?, ?, ?, ?, ?, ?)',
      [
        _core.newId('seed'),
        'bank',
        'salary',
        'income',
        18000000,
        DateTime(now.year, now.month, 1).toIso8601String(),
        'Lương tháng này',
        1,
      ],
    );
    db.execute(
      'insert into transactions values (?, ?, null, ?, ?, ?, ?, ?, ?)',
      [
        _core.newId('seed'),
        'cash',
        'food',
        'expense',
        180000,
        DateTime(now.year, now.month, now.day).toIso8601String(),
        'Cà phê và ăn trưa',
        0,
      ],
    );
    db.execute('insert into budgets values (?, ?, ?, ?)', [
      'budget-food',
      'food',
      DateTime(now.year, now.month).toIso8601String(),
      4500000,
    ]);
    db.execute('insert into saving_goals values (?, ?, ?, ?, ?)', [
      'goal-emergency',
      'Quỹ khẩn cấp',
      50000000,
      12500000,
      DateTime(now.year, now.month + 6, 1).toIso8601String(),
    ]);
  }

  void repairMojibake(Database db) {
    void repairWallet(String id, String correct) {
      for (final variant in _mojibakeVariants(correct)) {
        db.execute(
          'update wallets set name = ? where id = ? and name = ?',
          [correct, id, variant],
        );
      }
    }

    void repairCategory(String id, String correct) {
      for (final variant in _mojibakeVariants(correct)) {
        db.execute(
          'update categories set name = ? where id = ? and name = ?',
          [correct, id, variant],
        );
      }
    }

    void repairTransactionNote({
      required String walletId,
      required String categoryId,
      required String type,
      required int amount,
      required String correct,
    }) {
      for (final variant in _mojibakeVariants(correct)) {
        db.execute(
          'update transactions set note = ? where wallet_id = ? and category_id = ? and type = ? and amount = ? and note = ?',
          [correct, walletId, categoryId, type, amount, variant],
        );
      }
    }

    void repairGoal(String id, String correct) {
      for (final variant in _mojibakeVariants(correct)) {
        db.execute(
          'update saving_goals set name = ? where id = ? and name = ?',
          [correct, id, variant],
        );
      }
    }

    repairWallet('cash', 'Tiền mặt');
    repairWallet('bank', 'Ngân hàng');
    repairWallet('ewallet', 'Ví điện tử');
    repairCategory('salary', 'Lương');
    repairCategory('food', 'Ăn uống');
    repairCategory('transport', 'Di chuyển');
    repairCategory('bill', 'Hóa đơn');
    repairCategory('saving', 'Tiết kiệm');
    repairCategory('transfer', 'Chuyển ví');
    repairTransactionNote(
      walletId: 'bank',
      categoryId: 'salary',
      type: 'income',
      amount: 18000000,
      correct: 'Lương tháng này',
    );
    repairTransactionNote(
      walletId: 'cash',
      categoryId: 'food',
      type: 'expense',
      amount: 180000,
      correct: 'Cà phê và ăn trưa',
    );
    repairGoal('goal-emergency', 'Quỹ khẩn cấp');
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
      _insertMetadataIfMissing(db, 'wallet', row['id'] as String, now);
    }
    for (final row in db.select('select id from categories')) {
      _insertMetadataIfMissing(db, 'category', row['id'] as String, now);
    }
    for (final row in db.select('select id from transactions')) {
      _insertMetadataIfMissing(
        db, 'transaction', row['id'] as String, now,
      );
    }
    for (final row in db.select('select id from budgets')) {
      _insertMetadataIfMissing(db, 'budget', row['id'] as String, now);
    }
    for (final row in db.select('select id from saving_goals')) {
      _insertMetadataIfMissing(db, 'savingGoal', row['id'] as String, now);
    }
  }

  void _insertMetadataIfMissing(
    Database db, String entityType, String localId, String now,
  ) {
    db.execute(
      'insert or ignore into sync_metadata(entity_type, local_id, revision, updated_at) values (?, ?, 0, ?)',
      [entityType, localId, now],
    );
  }
}

Set<String> _mojibakeVariants(String value) {
  final variants = <String>{};
  void addEncodingVariants(String input) {
    final latin1Variant = latin1.decode(utf8.encode(input), allowInvalid: true);
    final windows1252Variant = _decodeWindows1252(utf8.encode(input));
    variants
      ..add(latin1Variant)
      ..add(windows1252Variant);
  }

  addEncodingVariants(value);
  for (final variant in variants.toList()) {
    addEncodingVariants(variant);
  }
  return variants;
}

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

String _nowIso() => DateTime.now().toUtc().toIso8601String();
