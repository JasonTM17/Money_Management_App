import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_theme.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import '../finance_controller.dart';
import 'budget_form_sheet.dart';
import 'home_common_widgets.dart';

class BudgetsTab extends StatelessWidget {
  const BudgetsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final calculator = const FinanceCalculator();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Ngân sách tháng này'),
        FilledButton.icon(
          onPressed: () => _showBudgetSheet(context),
          icon: const Icon(Icons.add_chart),
          label: const Text('Thêm ngân sách'),
        ),
        const SizedBox(height: 12),
        if (state.budgets.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(message: 'Chưa có ngân sách'),
          ),
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
            child: InkWell(
              onTap: () => _showBudgetSheet(context, budget),
              borderRadius: BorderRadius.circular(16),
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
                        IconButton(
                          tooltip: 'Xóa ngân sách',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () =>
                              _confirmDeleteBudget(context, budget),
                        ),
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
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showBudgetSheet(BuildContext context, [Budget? budget]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => BudgetFormSheet(budget: budget),
    );
  }

  Future<void> _confirmDeleteBudget(BuildContext context, Budget budget) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa ngân sách?'),
        content: const Text('Ngân sách này sẽ bị xóa khỏi tháng đã chọn.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ProviderScope.containerOf(
      context,
    ).read(financeControllerProvider.notifier).deleteBudget(budget.id);
  }
}
