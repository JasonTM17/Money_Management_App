import 'package:cashflow_manager/app/app_localizations.dart';
import 'package:cashflow_manager/core/export_service.dart';
import 'package:cashflow_manager/core/finance_backup_service.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports empty transactions with header row', () {
    final csv = const ExportService().transactionsToCsv(const []);

    expect(csv, contains('date,type,wallet_id,category_id,amount_vnd,note'));
  });

  test('escapes spreadsheet formulas in CSV string cells', () {
    final csv = const ExportService().transactionsToCsv([
      FinanceTransaction(
        id: 'txn-formula',
        walletId: '=cash',
        categoryId: '+food',
        type: TransactionType.expense,
        amount: 1000,
        date: DateTime(2026, 5),
        note: '=IMPORTXML("https://example.com")',
      ),
      FinanceTransaction(
        id: 'txn-control-formula',
        walletId: '\t=wallet',
        categoryId: '\r+category',
        type: TransactionType.expense,
        amount: 1000,
        date: DateTime(2026, 5),
        note: '\n@note',
      ),
    ]);

    expect(csv, contains("'="));
    expect(csv, contains("'+food"));
    expect(csv, contains("'\t=wallet"));
    expect(csv, contains("'\r+category"));
    expect(csv, contains("'\n@note"));
    expect(csv, isNot(contains(',=cash')));
    expect(csv, isNot(contains(',+food')));
    expect(csv, isNot(contains(',=IMPORTXML')));
    expect(csv, isNot(contains(',\t=wallet')));
    expect(csv, isNot(contains(',\r+category')));
    expect(csv, isNot(contains(',\n@note')));
  });

  test('localizes transfer transaction type in export labels', () {
    expect(
      const AppLocalizations(
        Locale('vi'),
      ).exportReportLabels.formatTransactionType(TransactionType.transfer),
      'Chuyển ví',
    );
    expect(
      const AppLocalizations(
        Locale('en'),
      ).exportReportLabels.formatTransactionType(TransactionType.transfer),
      'Transfer',
    );
    expect(
      const AppLocalizations(
        Locale('ja'),
      ).exportReportLabels.formatTransactionType(TransactionType.transfer),
      '送金',
    );
  });

  test('backup decode rejects invalid export timestamp', () {
    final backup = _validBackup().replaceFirst(
      RegExp(r'"exportedAt": "[^"]+"'),
      '"exportedAt": "invalid"',
    );

    expect(
      () => const FinanceBackupService().decode(backup),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'backupInvalidExportTime',
        ),
      ),
    );
  });

  test('backup decode rejects invalid enum values with localization key', () {
    final backup = _validBackup().replaceFirst(
      '"type": "cash"',
      '"type": "bad"',
    );

    expect(
      () => const FinanceBackupService().decode(backup),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'backupInvalidType',
        ),
      ),
    );
  });

  test('backup decode rejects invalid dates with localization key', () {
    final backup = _validBackup().replaceFirst(
      RegExp(r'"date": "[^"]+"'),
      '"date": "bad"',
    );

    expect(
      () => const FinanceBackupService().decode(backup),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'backupInvalidDate',
        ),
      ),
    );
  });

  test('backup preview returns safe counts before restore', () {
    final backup = const FinanceBackupService().encode(
      wallets: const [
        WalletAccount(
          id: 'cash',
          name: 'Tiền mặt',
          type: WalletType.cash,
          initialBalance: 1000000,
        ),
      ],
      categories: const [
        FinanceCategory(
          id: 'food',
          name: 'Ăn uống',
          type: TransactionType.expense,
          colorHex: 0xFFFF9800,
        ),
      ],
      transactions: [
        FinanceTransaction(
          id: 'txn',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 50000,
          date: DateTime(2026, 5),
          note: 'Ăn sáng',
        ),
      ],
      budgets: const [],
      goals: const [],
    );

    final preview = const FinanceBackupService().preview(backup);

    expect(preview.walletCount, 1);
    expect(preview.transactionCount, 1);
    expect(preview.budgetCount, 0);
    expect(preview.goalCount, 0);
    expect(preview.exportedAt, isNotNull);
  });

  test('monthly text report includes cashflow values', () {
    const summary = DashboardSummary(
      totalBalance: 1000000,
      monthIncome: 2000000,
      monthExpense: 750000,
      netCashflow: 1250000,
      budgetAlerts: ['food'],
    );

    final report = const ExportService().monthlyTextReport(summary);

    expect(report, contains('Báo cáo tháng'));
    expect(report, contains('Cảnh báo ngân sách: 1'));
  });

  test('monthly PDF report generates a valid PDF payload', () async {
    const summary = DashboardSummary(
      totalBalance: 1000000,
      monthIncome: 2000000,
      monthExpense: 750000,
      netCashflow: 1250000,
      budgetAlerts: ['food'],
    );

    final bytes = await const ExportService().monthlyPdfReport(
      summary: summary,
      transactions: [
        FinanceTransaction(
          id: 'txn',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 50000,
          date: DateTime(2026, 5),
          note: 'Ăn sáng',
        ),
      ],
    );

    expect(bytes.length, greaterThan(100));
    expect(String.fromCharCodes(bytes.take(4)), '%PDF');
  });
}

String _validBackup() => const FinanceBackupService().encode(
  wallets: const [
    WalletAccount(
      id: 'cash',
      name: 'Tiền mặt',
      type: WalletType.cash,
      initialBalance: 1000000,
    ),
  ],
  categories: const [
    FinanceCategory(
      id: 'food',
      name: 'Ăn uống',
      type: TransactionType.expense,
      colorHex: 0xFFFF9800,
    ),
  ],
  transactions: [
    FinanceTransaction(
      id: 'txn',
      walletId: 'cash',
      categoryId: 'food',
      type: TransactionType.expense,
      amount: 50000,
      date: DateTime(2026, 5),
      note: 'Ăn sáng',
    ),
  ],
  budgets: const [],
  goals: const [],
);
