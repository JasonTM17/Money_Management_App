import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class CategoryPieCard extends StatelessWidget {
  const CategoryPieCard({super.key, required this.state, required this.month});

  final FinanceState state;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final data = _categoryExpenses(state, month);
    final l10n = context.l10n;
    return SoftPanel(
      tint: Theme.of(context).colorScheme.tertiary,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: l10n.t('expenseCategoryChart')),
          if (data.isEmpty)
            EmptyState(
              icon: Icons.pie_chart_outline,
              message: l10n.t('categoryExpenseChartEmpty'),
            )
          else ...[
            Semantics(
              label: l10n.categoryExpenseChartSemantics(
                data
                    .map(
                      (item) =>
                          '${item.category.name} ${Money(item.amount).formatVnd()}',
                    )
                    .join(', '),
              ),
              child: SizedBox(
                height: 180,
                child: PieChart(
                  PieChartData(
                    centerSpaceRadius: 42,
                    sections: [
                      for (final item in data)
                        PieChartSectionData(
                          value: item.amount.toDouble(),
                          color: Color(item.category.colorHex),
                          title: '${item.percent}%',
                          radius: 58,
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in data)
                  Chip(
                    avatar: CircleAvatar(
                      backgroundColor: Color(item.category.colorHex),
                    ),
                    label: Text(
                      '${item.category.name}: ${Money(item.amount).formatVnd()}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class TopCategoryCard extends StatelessWidget {
  const TopCategoryCard({super.key, required this.state, required this.month});

  final FinanceState state;
  final DateTime month;

  @override
  Widget build(BuildContext context) {
    final data = _categoryExpenses(state, month).take(5).toList();
    final l10n = context.l10n;
    return SoftPanel(
      tint: Theme.of(context).colorScheme.primary,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSectionHeader(title: l10n.t('topExpenseCategories')),
          if (data.isEmpty)
            EmptyState(
              icon: Icons.leaderboard_outlined,
              message: l10n.t('topExpenseCategoriesEmpty'),
            )
          else
            ...data.map((item) {
              final color = Color(item.category.colorHex);
              return CompactListRow(
                icon: Icons.pie_chart,
                title: item.category.name,
                color: color,
                subtitle: '${item.percent}% ${l10n.t('expense')}',
                trailing: Text(
                  Money(item.amount).formatVnd(),
                  style: TextStyle(color: color, fontWeight: FontWeight.w900),
                ),
              );
            }),
        ],
      ),
    );
  }
}

List<_CategoryExpense> _categoryExpenses(FinanceState state, DateTime month) {
  final total = state.transactions
      .where(
        (item) =>
            item.type == TransactionType.expense &&
            item.date.year == month.year &&
            item.date.month == month.month,
      )
      .fold(0, (sum, item) => sum + item.amount);
  if (total == 0) return const [];
  final items = <_CategoryExpense>[];
  final calculator = const FinanceCalculator();
  for (final category in state.categories.where(
    (item) => item.type == TransactionType.expense,
  )) {
    final amount = calculator.categorySpend(
      transactions: state.transactions,
      categoryId: category.id,
      month: month,
    );
    if (amount == 0) continue;
    items.add(
      _CategoryExpense(category, amount, (amount * 100 / total).round()),
    );
  }
  items.sort((a, b) => b.amount.compareTo(a.amount));
  return items;
}

class _CategoryExpense {
  const _CategoryExpense(this.category, this.amount, this.percent);

  final FinanceCategory category;
  final int amount;
  final int percent;
}
