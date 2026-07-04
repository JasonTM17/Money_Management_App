import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_theme.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

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
      tint: AppTheme.incomeGreen,
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
                          color: AppTheme.incomeGreen,
                          width: 28,
                          borderRadius: BorderRadius.circular(
                            AppTheme.pillRadius,
                          ),
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
                          borderRadius: BorderRadius.circular(
                            AppTheme.pillRadius,
                          ),
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
                color: AppTheme.incomeGreen,
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
