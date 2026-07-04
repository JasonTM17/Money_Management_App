import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_theme.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'dashboard_summary_widgets.dart';
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
                    color: AppTheme.incomeGreen,
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
