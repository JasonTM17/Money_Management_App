import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        HeroBalanceCard(summary: summary),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Thu tháng này',
                value: Money(summary.monthIncome).formatVnd(),
                icon: Icons.trending_up,
                color: AppTheme.incomeBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: 'Chi tháng này',
                value: Money(summary.monthExpense).formatVnd(),
                icon: Icons.trending_down,
                color: AppTheme.expenseRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ChartCard(state: state),
        const SizedBox(height: 12),
        const SectionTitle('Giao dịch gần đây'),
        ...state.transactions
            .take(5)
            .map((item) => TransactionTile(transaction: item)),
        if (summary.budgetAlerts.isNotEmpty)
          AlertCard(count: summary.budgetAlerts.length),
      ],
    );
  }
}

class HeroBalanceCard extends StatelessWidget {
  const HeroBalanceCard({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.seed,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFF16A34A), Color(0xFF62DF7D)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tổng số dư hiện tại',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white.withValues(alpha: 0.82),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              Money(summary.totalBalance).formatVnd(),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'Net cashflow: ${Money(summary.netCashflow).formatVnd()}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Biểu đồ thu/chi'),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: state.summary.monthIncome.toDouble(),
                          color: AppTheme.incomeBlue,
                          width: 28,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: state.summary.monthExpense.toDouble(),
                          color: AppTheme.expenseRed,
                          width: 28,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.warningAmber.withValues(alpha: 0.18),
      child: ListTile(
        leading: const Icon(Icons.warning_amber, color: AppTheme.warningAmber),
        title: Text('$count ngân sách gần/vượt hạn mức'),
      ),
    );
  }
}
