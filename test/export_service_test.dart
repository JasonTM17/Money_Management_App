import 'package:cashflow_manager/core/export_service.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exports empty transactions with header row', () {
    final csv = const ExportService().transactionsToCsv(const []);

    expect(csv, contains('date,type,wallet_id,category_id,amount_vnd,note'));
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
