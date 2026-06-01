import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
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
    final l10n = context.l10n;
    return AppScrollView(
      children: [
        AppSectionHeader(
          title: l10n.t('budgetThisMonth'),
          action: SectionActionButton(
            label: l10n.t('addBudget'),
            icon: Icons.add_chart,
            onPressed: () => _showBudgetSheet(context),
          ),
        ),
        if (state.budgets.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: EmptyState(message: l10n.t('noBudgets')),
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
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftPanel(
              tint: progressColor,
              onTap: () => _showBudgetSheet(context, budget),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: progressColor.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isWarning ? Icons.warning_amber : Icons.track_changes,
                          color: progressColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          category?.name ?? budget.categoryId,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        tooltip: l10n.t('deleteBudget'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDeleteBudget(context, budget),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Semantics(
                    label: l10n.budgetProgressSemantics(
                      category?.name ?? budget.categoryId,
                      Money(spent).formatVnd(),
                      Money(budget.limitAmount).formatVnd(),
                    ),
                    child: LinearProgressIndicator(
                      value: progress,
                      color: progressColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Text(
                        '${Money(spent).formatVnd()} / ${Money(budget.limitAmount).formatVnd()}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        l10n.budgetRemaining(
                          Money(
                            (budget.limitAmount - spent).clamp(
                              0,
                              budget.limitAmount,
                            ),
                          ).formatVnd(),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
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
        title: Text(context.l10n.t('deleteBudgetQuestion')),
        content: Text(context.l10n.t('deleteBudgetWarning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.t('delete')),
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
