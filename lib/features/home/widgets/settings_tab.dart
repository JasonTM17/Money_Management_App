import 'package:flutter/material.dart';

import '../../../core/finance_calculator.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

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
