import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class CategoryPieCard extends StatelessWidget {
  const CategoryPieCard({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final data = _categoryExpenses(state);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Chi tiêu theo danh mục'),
            if (data.isEmpty)
              const Text('Chưa có chi tiêu trong tháng này')
            else ...[
              SizedBox(
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
      ),
    );
  }
}

class TopCategoryCard extends StatelessWidget {
  const TopCategoryCard({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final data = _categoryExpenses(state).take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Top category chi tiêu'),
            if (data.isEmpty)
              const Text('Chưa đủ dữ liệu xếp hạng')
            else
              ...data.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Color(
                      item.category.colorHex,
                    ).withValues(alpha: 0.14),
                    foregroundColor: Color(item.category.colorHex),
                    child: const Icon(Icons.pie_chart),
                  ),
                  title: Text(item.category.name),
                  subtitle: LinearProgressIndicator(
                    value: item.amount / data.first.amount,
                    color: Color(item.category.colorHex),
                  ),
                  trailing: Text(Money(item.amount).formatVnd()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

List<_CategoryExpense> _categoryExpenses(FinanceState state) {
  final now = DateTime.now();
  final total = state.transactions
      .where(
        (item) =>
            item.type == TransactionType.expense &&
            item.date.year == now.year &&
            item.date.month == now.month,
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
      month: now,
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
