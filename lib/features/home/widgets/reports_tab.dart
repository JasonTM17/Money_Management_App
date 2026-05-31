import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../app/app_localizations.dart';
import '../../../core/export_service.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'cashflow_forecast_card.dart';
import 'dashboard_tab.dart';
import 'home_common_widgets.dart';
import 'report_insight_cards.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, required this.state});

  final FinanceState state;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  late DateTime _selectedMonth = DateTime(
    widget.state.reportMonth.year,
    widget.state.reportMonth.month,
  );

  @override
  void didUpdateWidget(covariant ReportsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMonth = oldWidget.state.reportMonth;
    final newMonth = widget.state.reportMonth;
    if (oldMonth.year != newMonth.year || oldMonth.month != newMonth.month) {
      _selectedMonth = DateTime(newMonth.year, newMonth.month);
    }
  }

  @override
  Widget build(BuildContext context) {
    final exportService = const ExportService();
    final reportState = _reportState();
    final monthlyTransactions = _monthlyTransactions();
    final l10n = context.l10n;
    final report = exportService.monthlyTextReport(
      reportState.summary,
      month: _selectedMonth,
      labels: l10n.exportReportLabels,
    );
    final csv = exportService.transactionsToCsv(monthlyTransactions);
    return AppScrollView(
      children: [
        AppSectionHeader(title: l10n.t('reportMonth')),
        _MonthSelector(
          month: _selectedMonth,
          onPrevious: () => _changeMonth(-1),
          onNext: () => _changeMonth(1),
        ),
        const SizedBox(height: 12),
        ChartCard(state: reportState),
        const SizedBox(height: 12),
        CategoryPieCard(state: reportState, month: _selectedMonth),
        const SizedBox(height: 12),
        TopCategoryCard(state: reportState, month: _selectedMonth),
        const SizedBox(height: 12),
        CashflowForecastCard(state: widget.state, now: _selectedMonth),
        const SizedBox(height: 12),
        MetricCard(
          title: l10n.t('netCashflow'),
          value: Money(reportState.summary.netCashflow).formatVnd(),
          icon: Icons.show_chart,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        SoftPanel(
          padding: const EdgeInsets.all(18),
          child: Text(
            report,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.45,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: () => _showExportSheet(
            context,
            exportService,
            report,
            csv,
            reportState.summary,
            monthlyTransactions,
          ),
          icon: const Icon(Icons.file_download),
          label: Text(l10n.t('exportCsvPdf')),
        ),
      ],
    );
  }

  void _changeMonth(int offset) {
    setState(() {
      _selectedMonth = DateTime(
        _selectedMonth.year,
        _selectedMonth.month + offset,
      );
    });
  }

  FinanceState _reportState() {
    final summary = const FinanceCalculator().dashboardSummary(
      wallets: widget.state.wallets,
      transactions: widget.state.transactions,
      budgets: widget.state.budgets,
      month: _selectedMonth,
    );
    return FinanceState(
      wallets: widget.state.wallets,
      categories: widget.state.categories,
      transactions: widget.state.transactions,
      budgets: widget.state.budgets,
      goals: widget.state.goals,
      summary: summary,
      reportMonth: _selectedMonth,
    );
  }

  List<FinanceTransaction> _monthlyTransactions() {
    return widget.state.transactions
        .where(
          (item) =>
              item.date.year == _selectedMonth.year &&
              item.date.month == _selectedMonth.month,
        )
        .toList();
  }

  Future<void> _showExportSheet(
    BuildContext context,
    ExportService exportService,
    String report,
    String csv,
    DashboardSummary summary,
    List<FinanceTransaction> transactions,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => AppSheetScaffold(
        children: [
          SheetTitle(
            title: context.l10n.t('exportReportContent'),
            icon: Icons.file_download_outlined,
          ),
          const SizedBox(height: 12),
          Text(report),
          const SizedBox(height: 16),
          Text(
            context.l10n.t('csvTransactions'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.t('exportSensitiveWarning'),
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(csv),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () async {
              final bytes = await exportService.monthlyPdfReport(
                summary: summary,
                transactions: transactions,
                month: _selectedMonth,
                labels: context.l10n.exportReportLabels,
                wallets: widget.state.wallets,
                categories: widget.state.categories,
              );
              await Printing.sharePdf(
                bytes: bytes,
                filename: 'cashflow-manager-report.pdf',
              );
            },
            icon: const Icon(Icons.picture_as_pdf),
            label: Text(context.l10n.t('sharePdf')),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.t('close')),
          ),
        ],
      ),
    );
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = l10n.monthYear(month);
    return SoftPanel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.t('monthBefore'),
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  l10n.t('reportMonth'),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.t('monthAfter'),
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}
