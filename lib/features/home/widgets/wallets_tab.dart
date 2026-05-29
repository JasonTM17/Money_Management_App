import 'package:flutter/material.dart';

import '../../../core/finance_calculator.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';
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
        ...state.goals.map(
          (goal) => Card(
            child: ListTile(
              title: Text(goal.name),
              subtitle: LinearProgressIndicator(
                value: (goal.savedAmount / goal.targetAmount).clamp(0, 1),
              ),
              trailing: Text(
                Money(goal.targetAmount - goal.savedAmount).formatVnd(),
              ),
            ),
          ),
        ),
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
}
