import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import 'home_common_widgets.dart';

class CashflowForecastCard extends StatelessWidget {
  const CashflowForecastCard({
    super.key,
    required this.state,
    required this.now,
  });

  final FinanceState state;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
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
            .map((item) => _UpcomingBill(item, _nextOccurrence(item, now)))
            .where((item) => item.date.difference(now).inDays <= 31)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
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
                        item.transaction.note.isEmpty
                            ? item.transaction.categoryId
                            : item.transaction.note,
                      ),
                      subtitle: Text(
                        'Đến hạn ${item.date.day}/${item.date.month}',
                      ),
                      trailing: Text(
                        Money(item.transaction.amount).formatVnd(),
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _UpcomingBill {
  const _UpcomingBill(this.transaction, this.date);

  final FinanceTransaction transaction;
  final DateTime date;
}

DateTime _nextOccurrence(FinanceTransaction transaction, DateTime now) {
  final currentMonthDay = transaction.date.day.clamp(
    1,
    DateTime(now.year, now.month + 1, 0).day,
  );
  final currentMonth = DateTime(now.year, now.month, currentMonthDay);
  if (currentMonth.isAfter(now)) return currentMonth;
  final nextMonthDay = transaction.date.day.clamp(
    1,
    DateTime(now.year, now.month + 2, 0).day,
  );
  return DateTime(now.year, now.month + 1, nextMonthDay);
}
