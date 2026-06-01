import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_theme.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class MonthlyTrendCard extends StatelessWidget {
  const MonthlyTrendCard({
    super.key,
    required this.state,
    required this.endingMonth,
  });

  final FinanceState state;
  final DateTime endingMonth;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final trends = const FinanceCalculator().monthlyCashflowTrend(
      transactions: state.transactions,
      endingMonth: endingMonth,
      monthCount: 4,
    );
    final latest = trends.last;
    final maxAmount = trends.fold<int>(
      0,
      (current, item) => math.max(current, math.max(item.income, item.expense)),
    );
    return SoftPanel(
      tint: AppTheme.incomeBlue,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PanelTitle(l10n.t('monthlyTrend')),
          if (!trends.any((item) => item.hasActivity))
            EmptyState(
              icon: Icons.stacked_bar_chart,
              message: l10n.t('noTrendData'),
            )
          else ...[
            SizedBox(
              height: 168,
              child: Semantics(
                label: _trendSemantics(l10n, trends),
                child: BarChart(
                  BarChartData(
                    maxY: math.max(1, maxAmount).toDouble() * 1.18,
                    alignment: BarChartAlignment.spaceAround,
                    borderData: FlBorderData(show: false),
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (value) => FlLine(
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.32),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 38,
                          interval: math.max(1, maxAmount).toDouble() / 2,
                          getTitlesWidget: (value, meta) {
                            if (value <= 0) return const SizedBox.shrink();
                            return Text(
                              compactVndLabel(value),
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w800,
                                  ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= trends.length) {
                              return const SizedBox.shrink();
                            }
                            final month = trends[index].month;
                            return Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${month.month}/${month.year % 100}',
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: [
                      for (var index = 0; index < trends.length; index++)
                        BarChartGroupData(
                          x: index,
                          barsSpace: 4,
                          barRods: [
                            BarChartRodData(
                              toY: trends[index].income.toDouble(),
                              width: 10,
                              borderRadius: BorderRadius.circular(4),
                              color: AppTheme.incomeBlue,
                            ),
                            BarChartRodData(
                              toY: trends[index].expense.toDouble(),
                              width: 10,
                              borderRadius: BorderRadius.circular(4),
                              color: AppTheme.expenseRed,
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
                _LegendDot(color: AppTheme.incomeBlue, label: l10n.t('income')),
                _LegendDot(
                  color: AppTheme.expenseRed,
                  label: l10n.t('expense'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              l10n.netCashflow(Money(latest.netCashflow).formatVnd()),
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
          ],
        ],
      ),
    );
  }

  String _trendSemantics(
    AppLocalizations l10n,
    List<MonthlyCashflowTrend> trends,
  ) {
    return trends
        .map(
          (item) =>
              '${l10n.monthYear(item.month)} ${l10n.t('income')} ${Money(item.income).formatVnd()}, ${l10n.t('expense')} ${Money(item.expense).formatVnd()}',
        )
        .join('; ');
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

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
