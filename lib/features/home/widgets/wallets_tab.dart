import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Ví / tài khoản'),
        FilledButton.icon(
          onPressed: state.wallets.length < 2
              ? null
              : () => _showTransferSheet(context),
          icon: const Icon(Icons.swap_horiz),
          label: const Text('Chuyển tiền giữa ví'),
        ),
        const SizedBox(height: 12),
        ...state.wallets.map(
          (wallet) => Card(
            child: ListTile(
              leading: const Icon(Icons.account_balance_wallet),
              title: Text(wallet.name),
              subtitle: Text(walletTypeLabel(wallet.type)),
              trailing: Text(
                Money(balances[wallet.id] ?? 0).formatVnd(),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const SectionTitle('Mục tiêu tiết kiệm'),
        FilledButton.icon(
          onPressed: () => _showGoalSheet(context),
          icon: const Icon(Icons.savings),
          label: const Text('Thêm mục tiêu'),
        ),
        const SizedBox(height: 12),
        if (state.goals.isEmpty)
          const Card(
            child: ListTile(title: Text('Chưa có mục tiêu tiết kiệm')),
          ),
        ...state.goals.map((goal) {
          final progress = (goal.savedAmount / goal.targetAmount).clamp(
            0.0,
            1.0,
          );
          final remaining = (goal.targetAmount - goal.savedAmount).clamp(
            0,
            goal.targetAmount,
          );
          return Card(
            child: ListTile(
              onTap: () => _showGoalSheet(context, goal),
              title: Text(goal.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 6),
                  Text(
                    'Còn ${Money(remaining).formatVnd()} đến ${goal.deadline.day}/${goal.deadline.month}/${goal.deadline.year}',
                  ),
                ],
              ),
              trailing: IconButton(
                tooltip: 'Xóa mục tiêu',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmDeleteGoal(context, goal),
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
        title: const Text('Xóa mục tiêu?'),
        content: const Text('Mục tiêu tiết kiệm này sẽ bị xóa.'),
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
    ).read(financeControllerProvider.notifier).deleteGoal(goal.id);
  }
}
