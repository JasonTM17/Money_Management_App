import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class BudgetsTab extends StatelessWidget {
  const BudgetsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    if (state.budgets.isEmpty) {
      return const EmptyState(message: 'Chưa có ngân sách');
    }
    final calculator = const FinanceCalculator();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Ngân sách tháng này'),
        ...state.budgets.map((budget) {
          final category = state.categories
              .where((item) => item.id == budget.categoryId)
              .firstOrNull;
          final spent = calculator.categorySpend(
            transactions: state.transactions,
            categoryId: budget.categoryId,
            month: budget.month,
          );
          final progress = (spent / budget.limitAmount).clamp(0.0, 1.0);
          final progressColor = progress >= 1
              ? AppTheme.expenseRed
              : progress >= 0.8
              ? AppTheme.warningAmber
              : AppTheme.seed;
          final isWarning = progress >= 0.8;
          return Card(
            color: isWarning ? progressColor.withValues(alpha: 0.14) : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          category?.name ?? budget.categoryId,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      if (isWarning)
                        Icon(Icons.warning_amber, color: progressColor),
                    ],
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    color: progressColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${Money(spent).formatVnd()} / ${Money(budget.limitAmount).formatVnd()}',
                  ),
                  Text(
                    'Còn lại: ${Money((budget.limitAmount - spent).clamp(0, budget.limitAmount)).formatVnd()}',
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}
