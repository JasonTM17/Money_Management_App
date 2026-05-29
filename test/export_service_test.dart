import 'package:cashflow_manager/core/export_service.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exports empty transactions with header row', () {
    final csv = const ExportService().transactionsToCsv(const []);

    expect(csv, contains('date,type,wallet_id,category_id,amount_vnd,note'));
  });

  test('monthly text report includes cashflow values', () {
    const summary = DashboardSummary(totalBalance: 1000000, monthIncome: 2000000, monthExpense: 750000, netCashflow: 1250000, budgetAlerts: ['food']);

    final report = const ExportService().monthlyTextReport(summary);

    expect(report, contains('Báo cáo tháng'));
    expect(report, contains('Cảnh báo ngân sách: 1'));
  });
}
