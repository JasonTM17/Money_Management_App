import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../core/export_service.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'dashboard_tab.dart';
import 'home_common_widgets.dart';

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final exportService = const ExportService();
    final report = exportService.monthlyTextReport(state.summary);
    final csv = exportService.transactionsToCsv(state.transactions);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Báo cáo tháng'),
        ChartCard(state: state),
        const SizedBox(height: 12),
        MetricCard(
          title: 'Net cashflow',
          value: Money(state.summary.netCashflow).formatVnd(),
          icon: Icons.show_chart,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(report),
          ),
        ),
        FilledButton.icon(
          onPressed: () =>
              _showExportSheet(context, exportService, report, csv),
          icon: const Icon(Icons.file_download),
          label: const Text('Xuất CSV/PDF'),
        ),
      ],
    );
  }

  Future<void> _showExportSheet(
    BuildContext context,
    ExportService exportService,
    String report,
    String csv,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Nội dung xuất báo cáo',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              Text(report),
              const SizedBox(height: 16),
              Text(
                'CSV giao dịch',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              SelectableText(csv),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () async {
                  final bytes = await exportService.monthlyPdfReport(
                    summary: state.summary,
                    transactions: state.transactions,
                  );
                  await Printing.sharePdf(
                    bytes: bytes,
                    filename: 'cashflow-manager-report.pdf',
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Chia sẻ PDF'),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Đóng'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
