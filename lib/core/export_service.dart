import 'package:csv/csv.dart';

import 'finance_models.dart';
import 'money.dart';

class ExportService {
  const ExportService();

  String transactionsToCsv(List<FinanceTransaction> transactions) {
    final rows = <List<Object?>>[
      ['date', 'type', 'wallet_id', 'category_id', 'amount_vnd', 'note'],
      ...transactions.map(
        (item) => [
          item.date.toIso8601String(),
          item.type.name,
          item.walletId,
          item.categoryId,
          item.amount,
          item.note,
        ],
      ),
    ];
    return const ListToCsvConverter().convert(rows);
  }

  String monthlyTextReport(DashboardSummary summary) {
    return [
      'CashFlow Manager - Báo cáo tháng',
      'Tổng số dư: ${Money(summary.totalBalance).formatVnd()}',
      'Thu tháng này: ${Money(summary.monthIncome).formatVnd()}',
      'Chi tháng này: ${Money(summary.monthExpense).formatVnd()}',
      'Net cashflow: ${Money(summary.netCashflow).formatVnd()}',
      'Cảnh báo ngân sách: ${summary.budgetAlerts.length}',
    ].join('\n');
  }
}
