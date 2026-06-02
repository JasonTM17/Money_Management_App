import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import '../core/finance_calculator.dart';
import '../core/finance_models.dart';

class FinanceStoreCore {
  FinanceStoreCore({this.databasePath});

  Database? _db;
  final String? databasePath;
  final FinanceCalculator calculator = const FinanceCalculator();

  Future<Database> open() async {
    if (_db case final db?) return db;
    final path =
        databasePath ??
        p.join(
          (await getApplicationDocumentsDirectory()).path,
          'cashflow_manager.sqlite',
        );
    final db = sqlite3.open(path);
    _db = db;
    return db;
  }

  void close() {
    _db?.close();
    _db = null;
  }

  String newId(String prefix) =>
      '$prefix-${DateTime.now().microsecondsSinceEpoch}';

  WalletAccount walletFromRow(Row row) => WalletAccount(
    id: row['id'] as String,
    name: row['name'] as String,
    type: WalletType.values.byName(row['type'] as String),
    initialBalance: row['initial_balance'] as int,
  );

  FinanceCategory categoryFromRow(Row row) => FinanceCategory(
    id: row['id'] as String,
    name: row['name'] as String,
    type: TransactionType.values.byName(row['type'] as String),
    colorHex: row['color_hex'] as int,
  );

  FinanceTransaction transactionFromRow(Row row) => FinanceTransaction(
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

  Budget budgetFromRow(Row row) => Budget(
    id: row['id'] as String,
    categoryId: row['category_id'] as String,
    month: DateTime.parse(row['month'] as String),
    limitAmount: row['limit_amount'] as int,
  );

  SavingGoal goalFromRow(Row row) => SavingGoal(
    id: row['id'] as String,
    name: row['name'] as String,
    targetAmount: row['target_amount'] as int,
    savedAmount: row['saved_amount'] as int,
    deadline: DateTime.parse(row['deadline'] as String),
  );
}
