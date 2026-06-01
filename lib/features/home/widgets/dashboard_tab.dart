import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;

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
            final cardWidth = constraints.maxWidth >= 330
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
    final netPositive = summary.netCashflow >= 0;
    final colorScheme = Theme.of(context).colorScheme;
    return SoftPanel(
      tint: colorScheme.primary,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  context.l10n.t('totalBalance'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Text(
              Money(summary.totalBalance).formatVnd(),
              maxLines: 1,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) => ConstrainedBox(
              constraints: BoxConstraints(maxWidth: constraints.maxWidth),
              child: StatusPill(
                label: context.l10n.netCashflow(
                  Money(summary.netCashflow).formatVnd(),
                ),
                color: netPositive
                    ? colorScheme.primary
                    : AppTheme.warningAmber,
                icon: netPositive ? Icons.trending_up : Icons.trending_down,
              ),
            ),
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
    final maxAmount = math.max(
      state.summary.monthIncome,
      state.summary.monthExpense,
    );
    final chartMaxY = math.max(1, maxAmount).toDouble() * 1.18;
    return SoftPanel(
      tint: AppTheme.incomeBlue,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(context.l10n.t('cashflowThisMonth')),
          Semantics(
            label: context.l10n.incomeExpenseChartSemantics(
              Money(state.summary.monthIncome).formatVnd(),
              Money(state.summary.monthExpense).formatVnd(),
            ),
            child: SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  maxY: chartMaxY,
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
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 42,
                        interval: chartMaxY / 2,
                        getTitlesWidget: (value, meta) {
                          if (value <= 0) return const SizedBox.shrink();
                          return Text(
                            compactVndLabel(value),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                          );
                        },
                      ),
                    ),
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
                                  ?.copyWith(fontWeight: FontWeight.w700),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width - 84,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
        ],
      ),
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
