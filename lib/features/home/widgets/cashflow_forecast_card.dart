import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class CashflowForecastCard extends StatelessWidget {
  const CashflowForecastCard({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final calculator = const FinanceCalculator();
    final currentForecast = calculator.forecastEndBalance(
      currentBalance: state.summary.totalBalance,
      recurringTransactions: state.transactions,
      until: DateTime(now.year, now.month + 1, 0),
      now: now,
    );
    final nextForecast = calculator.forecastEndBalance(
      currentBalance: state.summary.totalBalance,
      recurringTransactions: state.transactions,
      until: DateTime(now.year, now.month + 2, 0),
      now: now,
    );
    final recurringBills =
        state.transactions
            .where(
              (item) =>
                  item.isRecurring && item.type == TransactionType.expense,
            )
            .toList()
          ..sort((a, b) => b.amount.compareTo(a.amount));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle('Dự báo dòng tiền'),
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    title: 'Cuối tháng này',
                    value: Money(currentForecast).formatVnd(),
                    icon: Icons.calendar_today,
                    color: AppTheme.seed,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: MetricCard(
                    title: 'Cuối tháng sau',
                    value: Money(nextForecast).formatVnd(),
                    icon: Icons.event_available,
                    color: Colors.teal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Nhắc hóa đơn sắp tới',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (recurringBills.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Chưa có giao dịch chi lặp lại'),
              )
            else
              ...recurringBills
                  .take(3)
                  .map(
                    (item) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.notifications_active_outlined),
                      title: Text(
                        item.note.isEmpty ? item.categoryId : item.note,
                      ),
                      subtitle: const Text('Lặp lại hằng tháng'),
                      trailing: Text(Money(item.amount).formatVnd()),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
