import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_theme.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import '../finance_controller.dart';
import 'home_common_widgets.dart';
import 'saving_goal_form_sheet.dart';
import 'wallet_transfer_sheet.dart';

class WalletsTab extends StatelessWidget {
  const WalletsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final balances = const FinanceCalculator().walletBalances(
      wallets: state.wallets,
      transactions: state.transactions,
    );
    final l10n = context.l10n;
    return AppScrollView(
      children: [
        AppSectionHeader(
          title: l10n.t('wallets'),
          action: SectionActionButton(
            label: l10n.t('transferBetweenWallets'),
            icon: Icons.swap_horiz,
            onPressed: state.wallets.length < 2
                ? null
                : () => _showTransferSheet(context),
          ),
        ),
        ...state.wallets.map(
          (wallet) =>
              _WalletCard(wallet: wallet, balance: balances[wallet.id] ?? 0),
        ),
        AppSectionHeader(
          title: l10n.t('goals'),
          action: SectionActionButton(
            label: l10n.t('addGoal'),
            icon: Icons.savings,
            onPressed: () => _showGoalSheet(context),
          ),
        ),
        if (state.goals.isEmpty)
          EmptyState(icon: Icons.savings, message: l10n.t('noSavingGoals')),
        ...state.goals.map((goal) {
          final progress = (goal.savedAmount / goal.targetAmount).clamp(
            0.0,
            1.0,
          );
          final remaining = (goal.targetAmount - goal.savedAmount).clamp(
            0,
            goal.targetAmount,
          );
          final monthlySaving = const FinanceCalculator().requiredMonthlySaving(
            goal,
            DateTime.now(),
          );
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: SoftPanel(
              tint: AppTheme.seed,
              onTap: () => _showGoalSheet(context, goal),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: AppTheme.seed.withValues(alpha: 0.13),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.flag_outlined,
                          color: AppTheme.seed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          goal.name,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      IconButton(
                        key: ValueKey('delete-goal-${goal.id}'),
                        tooltip: l10n.t('deleteGoal'),
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDeleteGoal(context, goal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Text(
                    l10n.remainingGoal(
                      Money(remaining).formatVnd(),
                      goal.deadline,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.monthlySavingSuggestion(
                      Money(monthlySaving).formatVnd(),
                    ),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _showTransferSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => WalletTransferSheet(state: state),
    );
  }

  Future<void> _showGoalSheet(BuildContext context, [SavingGoal? goal]) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => SavingGoalFormSheet(goal: goal),
    );
  }

  Future<void> _confirmDeleteGoal(BuildContext context, SavingGoal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.t('deleteGoalQuestion')),
        content: Text(context.l10n.t('deleteGoalWarning')),
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
    ).read(financeControllerProvider.notifier).deleteGoal(goal.id);
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({required this.wallet, required this.balance});

  final WalletAccount wallet;
  final int balance;

  @override
  Widget build(BuildContext context) {
    final color = switch (wallet.type) {
      WalletType.cash => AppTheme.warningAmber,
      WalletType.bank => AppTheme.incomeBlue,
      WalletType.eWallet => AppTheme.seed,
      WalletType.creditCard => AppTheme.expenseRed,
    };
    final icon = switch (wallet.type) {
      WalletType.cash => Icons.payments,
      WalletType.bank => Icons.account_balance,
      WalletType.eWallet => Icons.account_balance_wallet,
      WalletType.creditCard => Icons.credit_card,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftPanel(
        tint: color,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wallet.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    localizedWalletTypeLabel(context, wallet.type),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                Money(balance).formatVnd(),
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
