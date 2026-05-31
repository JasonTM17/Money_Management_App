import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
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
    final l10n = context.l10n;
    final categoryById = {
      for (final category in state.categories) category.id: category,
    };
    final walletById = {for (final wallet in state.wallets) wallet.id: wallet};
    return AppScrollView(
      children: [
        HeroBalanceCard(summary: summary),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = constraints.maxWidth >= 520
                ? (constraints.maxWidth - 12) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: MetricCard(
                    title: l10n.t('thisMonthIncome'),
                    value: Money(summary.monthIncome).formatVnd(),
                    icon: Icons.trending_up,
                    color: AppTheme.incomeBlue,
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: MetricCard(
                    title: l10n.t('thisMonthExpense'),
                    value: Money(summary.monthExpense).formatVnd(),
                    icon: Icons.trending_down,
                    color: AppTheme.expenseRed,
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        ChartCard(state: state),
        AppSectionHeader(title: l10n.t('recentTransactions')),
        if (state.transactions.isEmpty)
          EmptyState(message: l10n.t('noTransactions')),
        ...state.transactions
            .take(5)
            .map(
              (item) => TransactionTile(
                transaction: item,
                categoryLabel: categoryById[item.categoryId]?.name,
                walletLabel: walletById[item.walletId]?.name,
              ),
            ),
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
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: const LinearGradient(
          colors: [Color(0xFF063E2E), Color(0xFF16A34A), Color(0xFF62DF7D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seed.withValues(alpha: 0.28),
            blurRadius: 30,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Stack(
        children: [
          Positioned(
            right: -30,
            top: -38,
            child: Container(
              width: 132,
              height: 132,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: -50,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wallet, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.t('totalBalance'),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.84),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                Money(summary.totalBalance).formatVnd(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 14),
              StatusPill(
                label: context.l10n.netCashflow(
                  Money(summary.netCashflow).formatVnd(),
                ),
                color: Colors.white,
                icon: summary.netCashflow >= 0
                    ? Icons.trending_up
                    : Icons.trending_down,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    return SoftPanel(
      tint: AppTheme.incomeBlue,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: context.l10n.t('cashflowThisMonth')),
          Semantics(
            label: context.l10n.incomeExpenseChartSemantics(
              Money(state.summary.monthIncome).formatVnd(),
              Money(state.summary.monthExpense).formatVnd(),
            ),
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: Theme.of(
                        context,
                      ).dividerColor.withValues(alpha: 0.55),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(),
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final label = value == 0
                              ? context.l10n.t('income')
                              : context.l10n.t('expense');
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              label,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: state.summary.monthIncome.toDouble(),
                          color: AppTheme.incomeBlue,
                          width: 34,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: state.summary.monthExpense.toDouble(),
                          color: AppTheme.expenseRed,
                          width: 34,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _ChartLegend(
                color: AppTheme.incomeBlue,
                label:
                    '${context.l10n.t('income')} ${Money(state.summary.monthIncome).formatVnd()}',
              ),
              _ChartLegend(
                color: AppTheme.expenseRed,
                label:
                    '${context.l10n.t('expense')} ${Money(state.summary.monthExpense).formatVnd()}',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChartLegend extends StatelessWidget {
  const _ChartLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: InlineInfoCard(
        icon: Icons.warning_amber,
        title: context.l10n.budgetAlertCount(count),
        color: AppTheme.warningAmber,
      ),
    );
  }
}
