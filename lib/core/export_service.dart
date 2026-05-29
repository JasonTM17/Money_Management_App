import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  Future<Uint8List> monthlyPdfReport({
    required DashboardSummary summary,
    required List<FinanceTransaction> transactions,
  }) async {
    final font = await fontFromAssetBundle('assets/fonts/noto-sans-jp-vf.ttf');
    final document = pw.Document(
      title: 'CashFlow Manager - Báo cáo tháng',
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
          pw.Text('Báo cáo tháng', style: const pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: const ['Chỉ số', 'Giá trị'],
            data: [
              ['Tổng số dư', Money(summary.totalBalance).formatVnd()],
              ['Thu tháng này', Money(summary.monthIncome).formatVnd()],
              ['Chi tháng này', Money(summary.monthExpense).formatVnd()],
              ['Net cashflow', Money(summary.netCashflow).formatVnd()],
              ['Cảnh báo ngân sách', summary.budgetAlerts.length.toString()],
            ],
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Giao dịch gần đây',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          if (transactions.isEmpty)
            pw.Text('Chưa có giao dịch')
          else
            pw.TableHelper.fromTextArray(
              headers: const [
                'Ngày',
                'Loại',
                'Ví',
                'Danh mục',
                'Số tiền',
                'Ghi chú',
              ],
              data: transactions
                  .take(20)
                  .map(
                    (item) => [
                      '${item.date.day}/${item.date.month}/${item.date.year}',
                      item.type.name,
                      item.walletId,
                      item.categoryId,
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
