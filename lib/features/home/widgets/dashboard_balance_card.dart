import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_theme.dart';
import '../../../app/animated_balance.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import 'dashboard_mini_metric.dart';
import 'home_common_widgets.dart';

class HeroBalanceCard extends StatelessWidget {
  const HeroBalanceCard({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final netPositive = summary.netCashflow >= 0;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        color: isDark ? AppTheme.cardSlate : AppTheme.lightPanel,
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.cardSlate,
                  colorScheme.primary.withValues(alpha: 0.09),
                  AppTheme.surfaceSlate,
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.lightPanel,
                  Color(0xFFFFF8EA),
                  Color(0xFFF2EBDE),
                ],
              ),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.075)
              : colorScheme.outlineVariant.withValues(alpha: 0.88),
        ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppTheme.ink).withValues(
              alpha: isDark ? 0.30 : 0.075,
            ),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
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
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(
                      alpha: isDark ? 0.18 : 0.10,
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.lock_outline,
                    color: colorScheme.primary,
                    size: 19,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedBalance(
              value: Money(summary.totalBalance).formatVnd(),
              style:
                  Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    height: 1.02,
                  ) ??
                  const TextStyle(),
            ),
            const SizedBox(height: 14),
            StatusPill(
              label: context.l10n.netCashflow(
                Money(summary.netCashflow).formatVnd(),
              ),
              color: netPositive ? colorScheme.primary : AppTheme.warningAmber,
              icon: netPositive ? Icons.trending_up : Icons.trending_down,
            ),
            const SizedBox(height: 18),
            Divider(
              color: colorScheme.outlineVariant.withValues(
                alpha: isDark ? 0.24 : 0.82,
              ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 330;
                final children = [
                  DashboardMiniMetric(
                    label: context.l10n.t('income'),
                    value: Money(summary.monthIncome).formatVnd(),
                    color: AppTheme.incomeGreen,
                    icon: Icons.south_west,
                  ),
                  DashboardMiniMetric(
                    label: context.l10n.t('expense'),
                    value: Money(summary.monthExpense).formatVnd(),
                    color: AppTheme.expenseRed,
                    icon: Icons.north_east,
                  ),
                ];
                if (stacked) {
                  return Column(
                    children: [
                      children.first,
                      const SizedBox(height: 8),
                      children.last,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: children.first),
                    const SizedBox(width: 10),
                    Expanded(child: children.last),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
