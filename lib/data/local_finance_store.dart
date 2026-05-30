import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../core/finance_backup_service.dart';
import '../core/finance_calculator.dart';
import '../core/finance_models.dart';

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
  Database? _db;
  final _calculator = const FinanceCalculator();

  Future<Database> _open() async {
    if (_db case final db?) return db;
    final dir = await getApplicationDocumentsDirectory();
    final db = sqlite3.open(p.join(dir.path, 'cashflow_manager.sqlite'));
    _db = db;
    _migrate(db);
    _seed(db);
    return db;
  }

  Future<FinanceState> load() async {
    final db = await _open();
    return _stateFromDb(db);
  }

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

  Future<void> restoreBackup(String input) async {
    final backup = const FinanceBackupService().decode(input);
    final db = await _open();
    db.execute('begin immediate');
    try {
      db.execute('delete from transactions');
      db.execute('delete from budgets');
      db.execute('delete from saving_goals');
      db.execute('delete from categories');
      db.execute('delete from wallets');
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
    db.execute(
      'insert into transactions values (?, ?, null, ?, ?, ?, ?, ?, ?)',
      [
        _id('txn'),
        walletId,
        categoryId,
        type.name,
        amount,
        date.toIso8601String(),
        note,
        isRecurring ? 1 : 0,
      ],
    );
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
  }

  Future<void> deleteTransaction(String id) async {
    final db = await _open();
    db.execute('delete from transactions where id = ?', [id]);
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
    db.execute('begin immediate');
    try {
      db.execute(
        'insert into transactions values (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          _id('trf'),
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
    final monthKey = DateTime(month.year, month.month).toIso8601String();
    final existing = db.select(
      'select id from budgets where category_id = ? and month = ? limit 1',
      [categoryId, monthKey],
    );
    if (existing.isEmpty) {
      db.execute('insert into budgets values (?, ?, ?, ?)', [
        _id('budget'),
        categoryId,
        monthKey,
        limitAmount,
      ]);
      return;
    }
    db.execute('update budgets set limit_amount = ? where id = ?', [
      limitAmount,
      existing.first['id'],
    ]);
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
    final monthKey = DateTime(month.year, month.month).toIso8601String();
    db.execute(
      'update budgets set category_id = ?, month = ?, limit_amount = ? where id = ?',
      [categoryId, monthKey, limitAmount, id],
    );
  }

  Future<void> deleteBudget(String id) async {
    final db = await _open();
    db.execute('delete from budgets where id = ?', [id]);
  }

  Future<void> deleteGoal(String id) async {
    final db = await _open();
    db.execute('delete from saving_goals where id = ?', [id]);
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
    if (targetAmount <= 0) {
      throw ArgumentError.value(
        targetAmount,
        'targetAmount',
        'Target must be positive',
      );
    }
    if (savedAmount < 0 || savedAmount > targetAmount) {
      throw ArgumentError.value(
        savedAmount,
        'savedAmount',
        'Saved amount must be between zero and target',
      );
    }
    final db = await _open();
    if (id == null) {
      db.execute('insert into saving_goals values (?, ?, ?, ?, ?)', [
        _id('goal'),
        name.trim(),
        targetAmount,
        savedAmount,
        deadline.toIso8601String(),
      ]);
      return;
    }
    db.execute(
      'update saving_goals set name = ?, target_amount = ?, saved_amount = ?, deadline = ? where id = ?',
      [name.trim(), targetAmount, savedAmount, deadline.toIso8601String(), id],
    );
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
