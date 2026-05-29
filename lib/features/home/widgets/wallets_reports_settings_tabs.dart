import 'package:flutter/material.dart';

import '../../../core/export_service.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'dashboard_tab.dart';
import 'home_common_widgets.dart';

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
}

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final report = const ExportService().monthlyTextReport(state.summary);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Báo cáo tháng'),
        ChartCard(state: state),
        const SizedBox(height: 12),
        MetricCard(
          title: 'Net cashflow',
          value: Money(state.summary.netCashflow).formatVnd(),
          icon: Icons.show_chart,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(report),
          ),
        ),
        FilledButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.file_download),
          label: const Text('Xuất CSV/PDF'),
        ),
      ],
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final forecast = const FinanceCalculator().forecastEndBalance(
      currentBalance: state.summary.totalBalance,
      recurringTransactions: state.transactions,
      until: DateTime(DateTime.now().year, DateTime.now().month + 1, 1),
      now: DateTime.now(),
    );
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Dòng tiền tương lai'),
        MetricCard(
          title: 'Dự kiến cuối tháng sau',
          value: Money(forecast).formatVnd(),
          icon: Icons.calendar_month,
          color: Colors.teal,
        ),
        const SizedBox(height: 12),
        const SectionTitle('Cài đặt'),
        const Card(
          child: SwitchListTile(
            value: true,
            onChanged: null,
            title: Text('Privacy lock / PIN sinh trắc học'),
            subtitle: Text('PIN fallback, biometric nếu thiết bị hỗ trợ'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.currency_exchange),
            title: Text('Tiền tệ mặc định'),
            subtitle: Text('VND'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.backup),
            title: Text('Backup / restore'),
            subtitle: Text('Offline trước, cloud sync ở roadmap'),
          ),
        ),
        const Card(
          child: ListTile(
            leading: Icon(Icons.delete_forever),
            title: Text('Reset data'),
            subtitle: Text('Yêu cầu xác nhận trước khi xóa'),
          ),
        ),
      ],
    );
  }
}
