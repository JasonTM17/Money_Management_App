import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'finance_models.dart';
import 'money.dart';

class ExportReportLabels {
  const ExportReportLabels({
    required this.title,
    required this.reportMonth,
    required this.reportPeriod,
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.netCashflow,
    required this.budgetAlerts,
    required this.metric,
    required this.value,
    required this.recentTransactions,
    required this.noTransactions,
    required this.date,
    required this.type,
    required this.wallet,
    required this.category,
    required this.amount,
    required this.note,
    required this.formatDate,
    required this.formatTransactionType,
  });

  final String title;
  final String reportMonth;
  final String Function(DateTime month) reportPeriod;
  final String totalBalance;
  final String monthIncome;
  final String monthExpense;
  final String netCashflow;
  final String budgetAlerts;
  final String metric;
  final String value;
  final String recentTransactions;
  final String noTransactions;
  final String date;
  final String type;
  final String wallet;
  final String category;
  final String amount;
  final String note;
  final String Function(DateTime date) formatDate;
  final String Function(TransactionType type) formatTransactionType;

  static ExportReportLabels vi() => ExportReportLabels(
    title: 'CashFlow Manager - Báo cáo tháng',
    reportMonth: 'Báo cáo tháng',
    reportPeriod: (month) => 'Kỳ báo cáo: ${month.month}/${month.year}',
    totalBalance: 'Tổng số dư hiện tại',
    monthIncome: 'Thu tháng này',
    monthExpense: 'Chi tháng này',
    netCashflow: 'Dòng tiền ròng',
    budgetAlerts: 'Cảnh báo ngân sách',
    metric: 'Chỉ số',
    value: 'Giá trị',
    recentTransactions: 'Giao dịch gần đây',
    noTransactions: 'Chưa có giao dịch',
    date: 'Ngày',
    type: 'Loại',
    wallet: 'Ví',
    category: 'Danh mục',
    amount: 'Số tiền',
    note: 'Ghi chú',
    formatDate: (date) => '${date.day}/${date.month}/${date.year}',
    formatTransactionType: (type) => switch (type) {
      TransactionType.income => 'Thu',
      TransactionType.expense => 'Chi',
      TransactionType.transfer => 'Chuyển ví',
    },
  );
}

class ExportService {
  const ExportService();

  String transactionsToCsv(List<FinanceTransaction> transactions) {
    final rows = <List<dynamic>>[
      ['date', 'type', 'wallet_id', 'category_id', 'amount_vnd', 'note'],
      ...transactions.map(
        (item) => [
          item.date.toIso8601String(),
          item.type.name,
          item.walletId,
          item.categoryId,
          item.amount,
          item.note,
        ].map(_escapeSpreadsheetFormulaCell).toList(),
      ),
    ];
    return csv.encode(rows);
  }

  Object? _escapeSpreadsheetFormulaCell(Object? value) {
    if (value is! String || value.isEmpty) return value;
    final firstCodeUnit = value.codeUnitAt(0);
    if (!'=+-@'.contains(value[0]) &&
        firstCodeUnit != 9 &&
        firstCodeUnit != 10 &&
        firstCodeUnit != 13) {
      return value;
    }
    return "'$value";
  }

  String monthlyTextReport(
    DashboardSummary summary, {
    DateTime? month,
    ExportReportLabels? labels,
  }) {
    final copy = labels ?? ExportReportLabels.vi();
    return [
      copy.title,
      if (month != null) copy.reportPeriod(month),
      '${copy.totalBalance}: ${Money(summary.totalBalance).formatVnd()}',
      '${copy.monthIncome}: ${Money(summary.monthIncome).formatVnd()}',
      '${copy.monthExpense}: ${Money(summary.monthExpense).formatVnd()}',
      '${copy.netCashflow}: ${Money(summary.netCashflow).formatVnd()}',
      '${copy.budgetAlerts}: ${summary.budgetAlerts.length}',
    ].join('\n');
  }

  Future<Uint8List> monthlyPdfReport({
    required DashboardSummary summary,
    required List<FinanceTransaction> transactions,
    List<WalletAccount> wallets = const [],
    List<FinanceCategory> categories = const [],
    DateTime? month,
    ExportReportLabels? labels,
  }) async {
    final copy = labels ?? ExportReportLabels.vi();
    final walletNames = {for (final wallet in wallets) wallet.id: wallet.name};
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    final font = await fontFromAssetBundle('assets/fonts/noto-sans-jp-vf.ttf');
    final document = pw.Document(
      title: copy.title,
      theme: pw.ThemeData.withFont(base: font, bold: font),
    );
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(
            'CashFlow Manager',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(copy.reportMonth, style: const pw.TextStyle(fontSize: 18)),
          if (month != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(copy.reportPeriod(month)),
          ],
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: [copy.metric, copy.value],
            data: [
              [copy.totalBalance, Money(summary.totalBalance).formatVnd()],
              [copy.monthIncome, Money(summary.monthIncome).formatVnd()],
              [copy.monthExpense, Money(summary.monthExpense).formatVnd()],
              [copy.netCashflow, Money(summary.netCashflow).formatVnd()],
              [copy.budgetAlerts, summary.budgetAlerts.length.toString()],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            copy.recentTransactions,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (transactions.isEmpty)
            pw.Text(copy.noTransactions)
          else
            pw.TableHelper.fromTextArray(
              headers: [
                copy.date,
                copy.type,
                copy.wallet,
                copy.category,
                copy.amount,
                copy.note,
              ],
              data: transactions
                  .take(20)
                  .map(
                    (item) => [
                      copy.formatDate(item.date),
                      copy.formatTransactionType(item.type),
                      walletNames[item.walletId] ?? item.walletId,
                      categoryNames[item.categoryId] ?? item.categoryId,
                      Money(item.amount).formatVnd(),
                      item.note,
                    ],
                  )
                  .toList(),
            ),
        ],
      ),
    );
    return document.save();
  }
}
