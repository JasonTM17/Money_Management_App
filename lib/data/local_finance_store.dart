import 'dart:convert';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../core/finance_backup_service.dart';
import '../core/finance_calculator.dart';
import '../core/finance_models.dart';
import '../core/sync_models.dart';

part 'local-finance-sync-metadata.dart';
part 'local-finance-local-validation.dart';
part 'local-finance-backup-restore.dart';

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
  // Public name keeps tests and callers readable while storing internally.
  // ignore: prefer_initializing_formals
  LocalFinanceStore({String? databasePath}) : _databasePath = databasePath;

  Database? _db;
  final String? _databasePath;
  final _calculator = const FinanceCalculator();

  Future<Database> _open() async {
    if (_db case final db?) return db;
    final databasePath = _databasePath;
    final path =
        databasePath ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'cashflow_manager.sqlite',
        );
    final db = sqlite3.open(path);
    _db = db;
    _migrate(db);
    _seed(db);
    _repairMojibakeStarterText(db);
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
      _deleteAllData(db);
      _deleteAllSyncState(db);
      _seed(db);
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
  }) async {
    if (amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'Amount must be positive');
    }
    final db = await _open();
    _assertWalletExists(db, walletId);
    _assertCategoryExists(db, categoryId, expectedType: type);
    final id = _id('txn');
    final payload = _transactionPayload(
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
      db.execute(
        'insert into transactions values (?, ?, null, ?, ?, ?, ?, ?, ?)',
        [
          id,
          walletId,
          categoryId,
          type.name,
          amount,
          date.toIso8601String(),
          note,
          isRecurring ? 1 : 0,
        ],
      );
      _markLocalCreate(db, entityType: _syncEntityTransaction, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntityTransaction,
        localId: id,
        operation: _syncOperationCreate,
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
    final db = await _open();
    _assertWalletExists(db, walletId);
    _assertCategoryExists(db, categoryId, expectedType: type);
    final payload = _transactionPayload(
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
      db.execute(
        'update transactions set wallet_id = ?, to_wallet_id = null, category_id = ?, type = ?, amount = ?, date = ?, note = ?, is_recurring = ? where id = ?',
        [
          walletId,
          categoryId,
          type.name,
          amount,
          date.toIso8601String(),
          note,
          isRecurring ? 1 : 0,
          id,
        ],
      );
      _markLocalUpdate(db, entityType: _syncEntityTransaction, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntityTransaction,
        localId: id,
        operation: _syncOperationUpdate,
        payload: payload,
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _open();
    db.execute('begin immediate');
    try {
      db.execute('delete from transactions where id = ?', [id]);
      _markLocalDelete(db, entityType: _syncEntityTransaction, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntityTransaction,
        localId: id,
        operation: _syncOperationDelete,
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
    final db = await _open();
    _assertWalletExists(db, fromWalletId);
    _assertWalletExists(db, toWalletId);
    _assertCategoryExists(
      db,
      'transfer',
      expectedType: TransactionType.transfer,
    );
    final localId = _id('trf');
    db.execute('begin immediate');
    try {
      db.execute(
        'insert into transactions values (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          localId,
          fromWalletId,
          toWalletId,
          'transfer',
          'transfer',
          amount,
          date.toIso8601String(),
          note,
          0,
        ],
      );
      _markLocalCreate(
        db,
        entityType: _syncEntityTransaction,
        localId: localId,
      );
      _enqueueLocalMutation(
        db,
        entityType: _syncEntityTransaction,
        localId: localId,
        operation: _syncOperationCreate,
        payload: _transactionPayload(
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

  Future<void> upsertBudget({
    required String categoryId,
    required DateTime month,
    required int limitAmount,
  }) async {
    if (limitAmount <= 0) {
      throw ArgumentError.value(
        limitAmount,
        'limitAmount',
        'Limit must be positive',
      );
    }
    final db = await _open();
    _assertBudgetMonthFirstDay(month);
    _assertCategoryExists(
      db,
      categoryId,
      expectedType: TransactionType.expense,
    );
    final monthKey = DateTime(month.year, month.month).toIso8601String();
    final existing = db.select(
      'select id from budgets where category_id = ? and month = ? limit 1',
      [categoryId, monthKey],
    );
    if (existing.isEmpty) {
      final id = _id('budget');
      db.execute('begin immediate');
      try {
        db.execute('insert into budgets values (?, ?, ?, ?)', [
          id,
          categoryId,
          monthKey,
          limitAmount,
        ]);
        _markLocalCreate(db, entityType: _syncEntityBudget, localId: id);
        _enqueueLocalMutation(
          db,
          entityType: _syncEntityBudget,
          localId: id,
          operation: _syncOperationCreate,
          payload: _budgetPayload(
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
      db.execute('update budgets set limit_amount = ? where id = ?', [
        limitAmount,
        id,
      ]);
      _markLocalUpdate(db, entityType: _syncEntityBudget, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntityBudget,
        localId: id,
        operation: _syncOperationUpdate,
        payload: _budgetPayload(
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
      throw ArgumentError.value(
        limitAmount,
        'limitAmount',
        'Limit must be positive',
      );
    }
    final db = await _open();
    _assertBudgetMonthFirstDay(month);
    _assertCategoryExists(
      db,
      categoryId,
      expectedType: TransactionType.expense,
    );
    final monthKey = DateTime(month.year, month.month).toIso8601String();
    db.execute('begin immediate');
    try {
      db.execute(
        'update budgets set category_id = ?, month = ?, limit_amount = ? where id = ?',
        [categoryId, monthKey, limitAmount, id],
      );
      _markLocalUpdate(db, entityType: _syncEntityBudget, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntityBudget,
        localId: id,
        operation: _syncOperationUpdate,
        payload: _budgetPayload(
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
    final db = await _open();
    db.execute('begin immediate');
    try {
      db.execute('delete from budgets where id = ?', [id]);
      _markLocalDelete(db, entityType: _syncEntityBudget, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntityBudget,
        localId: id,
        operation: _syncOperationDelete,
        payload: const {},
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  Future<void> deleteGoal(String id) async {
    final db = await _open();
    db.execute('begin immediate');
    try {
      db.execute('delete from saving_goals where id = ?', [id]);
      _markLocalDelete(db, entityType: _syncEntitySavingGoal, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntitySavingGoal,
        localId: id,
        operation: _syncOperationDelete,
        payload: const {},
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

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
    _assertSavingGoalAmounts(
      targetAmount: targetAmount,
      savedAmount: savedAmount,
    );
    final db = await _open();
    if (id == null) {
      final localId = _id('goal');
      db.execute('begin immediate');
      try {
        db.execute('insert into saving_goals values (?, ?, ?, ?, ?)', [
          localId,
          name.trim(),
          targetAmount,
          savedAmount,
          deadline.toIso8601String(),
        ]);
        _markLocalCreate(
          db,
          entityType: _syncEntitySavingGoal,
          localId: localId,
        );
        _enqueueLocalMutation(
          db,
          entityType: _syncEntitySavingGoal,
          localId: localId,
          operation: _syncOperationCreate,
          payload: _savingGoalPayload(
            name: name.trim(),
            targetAmount: targetAmount,
            savedAmount: savedAmount,
            deadline: deadline,
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
        [
          name.trim(),
          targetAmount,
          savedAmount,
          deadline.toIso8601String(),
          id,
        ],
      );
      _markLocalUpdate(db, entityType: _syncEntitySavingGoal, localId: id);
      _enqueueLocalMutation(
        db,
        entityType: _syncEntitySavingGoal,
        localId: id,
        operation: _syncOperationUpdate,
        payload: _savingGoalPayload(
          name: name.trim(),
          targetAmount: targetAmount,
          savedAmount: savedAmount,
          deadline: deadline,
        ),
      );
      db.execute('commit');
    } on Object {
      db.execute('rollback');
      rethrow;
    }
  }

  FinanceState _stateFromDb(Database db) {
    final wallets = db
        .select('select * from wallets order by name')
        .map(_walletFromRow)
        .toList();
    final categories = db
        .select('select * from categories order by type, name')
        .map(_categoryFromRow)
        .toList();
    final transactions = db
        .select('select * from transactions order by date desc')
        .map(_transactionFromRow)
        .toList();
    final budgets = db
        .select('select * from budgets')
        .map(_budgetFromRow)
        .toList();
    final goals = db
        .select('select * from saving_goals order by deadline')
        .map(_goalFromRow)
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

  void _migrate(Database db) {
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
    final transactionColumns = db
        .select('pragma table_info(transactions)')
        .map((row) => row['name'] as String)
        .toSet();
    if (!transactionColumns.contains('is_recurring')) {
      db.execute(
        'alter table transactions add column is_recurring integer not null default 0',
      );
    }
    db.execute(
      'create index if not exists idx_transactions_date on transactions(date desc)',
    );
    db.execute(
      'create index if not exists idx_transactions_wallet on transactions(wallet_id)',
    );
    db.execute(
      'create index if not exists idx_transactions_category_date on transactions(category_id, date)',
    );
    _cleanInvalidRows(db);
    _ensureSyncMetadataForExistingRows(db);
    db.execute(
      'create unique index if not exists idx_budgets_category_month on budgets(category_id, month)',
    );
  }

  void _cleanInvalidRows(Database db) {
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

  void _deleteAllData(Database db) {
    db.execute('delete from transactions');
    db.execute('delete from budgets');
    db.execute('delete from saving_goals');
    db.execute('delete from categories');
    db.execute('delete from wallets');
  }

  void _seed(Database db) {
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
        _id('seed'),
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
        _id('seed'),
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

  void _repairMojibakeStarterText(Database db) {
    void repairWallet(String id, String correct) {
      for (final variant in _mojibakeVariants(correct)) {
        db.execute('update wallets set name = ? where id = ? and name = ?', [
          correct,
          id,
          variant,
        ]);
      }
    }

    void repairCategory(String id, String correct) {
      for (final variant in _mojibakeVariants(correct)) {
        db.execute('update categories set name = ? where id = ? and name = ?', [
          correct,
          id,
          variant,
        ]);
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

  Set<String> _mojibakeVariants(String value) {
    final variants = <String>{};
    void addEncodingVariants(String input) {
      final latin1Variant = latin1.decode(
        utf8.encode(input),
        allowInvalid: true,
      );
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

  WalletAccount _walletFromRow(Row row) => WalletAccount(
    id: row['id'] as String,
    name: row['name'] as String,
    type: WalletType.values.byName(row['type'] as String),
    initialBalance: row['initial_balance'] as int,
  );
  FinanceCategory _categoryFromRow(Row row) => FinanceCategory(
    id: row['id'] as String,
    name: row['name'] as String,
    type: TransactionType.values.byName(row['type'] as String),
    colorHex: row['color_hex'] as int,
  );
  FinanceTransaction _transactionFromRow(Row row) => FinanceTransaction(
    id: row['id'] as String,
    walletId: row['wallet_id'] as String,
    toWalletId: row['to_wallet_id'] as String?,
    categoryId: row['category_id'] as String,
    type: TransactionType.values.byName(row['type'] as String),
    amount: row['amount'] as int,
    date: DateTime.parse(row['date'] as String),
    note: row['note'] as String,
    isRecurring: (row['is_recurring'] as int) == 1,
  );
  Budget _budgetFromRow(Row row) => Budget(
    id: row['id'] as String,
    categoryId: row['category_id'] as String,
    month: DateTime.parse(row['month'] as String),
    limitAmount: row['limit_amount'] as int,
  );
  SavingGoal _goalFromRow(Row row) => SavingGoal(
    id: row['id'] as String,
    name: row['name'] as String,
    targetAmount: row['target_amount'] as int,
    savedAmount: row['saved_amount'] as int,
    deadline: DateTime.parse(row['deadline'] as String),
  );
  String _id(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';
}
