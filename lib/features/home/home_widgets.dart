import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/export_service.dart';
import '../../core/finance_calculator.dart';
import '../../core/finance_models.dart';
import '../../core/money.dart';
import '../../data/local_finance_store.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final summary = state.summary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        HeroBalanceCard(summary: summary),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: MetricCard(
                title: 'Thu tháng này',
                value: Money(summary.monthIncome).formatVnd(),
                icon: Icons.trending_up,
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: MetricCard(
                title: 'Chi tháng này',
                value: Money(summary.monthExpense).formatVnd(),
                icon: Icons.trending_down,
                color: Colors.red,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ChartCard(state: state),
        const SizedBox(height: 12),
        const SectionTitle('Giao dịch gần đây'),
        ...state.transactions
            .take(5)
            .map((item) => TransactionTile(transaction: item)),
        if (summary.budgetAlerts.isNotEmpty)
          AlertCard(count: summary.budgetAlerts.length),
      ],
    );
  }
}

class TransactionsTab extends StatelessWidget {
  const TransactionsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    if (state.transactions.isEmpty) {
      return const EmptyState(message: 'Chưa có giao dịch');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: state.transactions
          .map((item) => TransactionTile(transaction: item))
          .toList(),
    );
  }
}

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
      padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.all(16),
      children: [
        const SectionTitle('Báo cáo tháng'),
        ChartCard(state: state),
        const SizedBox(height: 12),
        MetricCard(
          title: 'Net cashflow',
          value: Money(state.summary.netCashflow).formatVnd(),
          icon: Icons.show_chart,
          color: Colors.green,
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
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
      padding: const EdgeInsets.all(16),
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

class HeroBalanceCard extends StatelessWidget {
  const HeroBalanceCard({super.key, required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Tổng số dư hiện tại'),
            const SizedBox(height: 8),
            Text(
              Money(summary.totalBalance).formatVnd(),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Net cashflow: ${Money(summary.netCashflow).formatVnd()}'),
          ],
        ),
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(title),
            Text(value, style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}

class ChartCard extends StatelessWidget {
  const ChartCard({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Biểu đồ thu/chi'),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    leftTitles: AxisTitles(),
                    topTitles: AxisTitles(),
                    rightTitles: AxisTitles(),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: state.summary.monthIncome.toDouble(),
                          color: Colors.blue,
                          width: 28,
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: state.summary.monthExpense.toDouble(),
                          color: Colors.red,
                          width: 28,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});

  final FinanceTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(isIncome ? Icons.arrow_downward : Icons.arrow_upward),
        ),
        title: Text(
          transaction.note.isEmpty ? transaction.categoryId : transaction.note,
        ),
        subtitle: Text(
          '${transaction.categoryId} • ${transaction.date.day}/${transaction.date.month}/${transaction.date.year}',
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'}${Money(transaction.amount).formatVnd()}',
          style: TextStyle(
            color: isIncome ? Colors.blue : Colors.red,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.withValues(alpha: 0.18),
      child: ListTile(
        leading: const Icon(Icons.warning_amber),
        title: Text('$count ngân sách gần/vượt hạn mức'),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Center(child: Text(message));
}

String walletTypeLabel(WalletType type) => switch (type) {
  WalletType.cash => 'Tiền mặt',
  WalletType.bank => 'Ngân hàng',
  WalletType.eWallet => 'Ví điện tử',
  WalletType.creditCard => 'Thẻ tín dụng',
};
