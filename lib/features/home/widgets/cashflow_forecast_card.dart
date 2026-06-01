import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_theme.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class CashflowForecastCard extends StatelessWidget {
  const CashflowForecastCard({
    super.key,
    required this.state,
    required this.now,
  });

  final FinanceState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final calculator = const FinanceCalculator();
    final l10n = context.l10n;
    final currentForecast = calculator.forecastEndBalance(
      currentBalance: state.summary.totalBalance,
      recurringTransactions: state.transactions,
      until: DateTime(now.year, now.month + 1, 0),
      now: now,
    );
    final nextForecast = calculator.forecastEndBalance(
      currentBalance: state.summary.totalBalance,
      recurringTransactions: state.transactions,
      until: DateTime(now.year, now.month + 2, 0),
      now: now,
    );
    final recurringBills = calculator.upcomingRecurringBills(
      transactions: state.transactions,
      now: now,
    );
    return SoftPanel(
      tint: AppTheme.seed,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: l10n.t('cashflowForecast')),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth >= 420
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: width,
                    child: _ForecastTile(
                      title: l10n.t('forecastCurrentMonthEnd'),
                      value: Money(currentForecast).formatVnd(),
                      icon: Icons.calendar_today,
                      color: AppTheme.seed,
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: _ForecastTile(
                      title: l10n.t('forecastNextMonthEnd'),
                      value: Money(nextForecast).formatVnd(),
                      icon: Icons.event_available,
                      color: Colors.teal,
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            l10n.t('nextBills'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (recurringBills.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmptyState(
                icon: Icons.notifications_none,
                message: l10n.t('noRecurringExpenses'),
              ),
            )
          else
            ...recurringBills
                .take(3)
                .map(
                  (item) => CompactListRow(
                    icon: Icons.notifications_active_outlined,
                    color: AppTheme.warningAmber,
                    title: item.transaction.note.isEmpty
                        ? item.transaction.categoryId
                        : item.transaction.note,
                    subtitle: item.includedInForecast
                        ? '${l10n.dueDate(item.dueDate)} · ${l10n.t('includedInForecast')}'
                        : l10n.dueDate(item.dueDate),
                    trailing: Text(
                      Money(item.transaction.amount).formatVnd(),
                      style: const TextStyle(
                        color: AppTheme.expenseRed,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _ForecastTile extends StatelessWidget {
  const _ForecastTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
