import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/finance_models.dart';
import '../../data/local_finance_store.dart';
import 'finance_controller.dart';
import 'home_widgets.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    final finance = ref.watch(financeControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('CashFlow Manager')),
      body: finance.when(
        data: (state) => _tabs(state)[_index],
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) =>
            Center(child: Text('Không tải được dữ liệu: $error')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransaction(context),
        icon: const Icon(Icons.add),
        label: const Text('Thêm giao dịch'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Tổng quan',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long),
            label: 'Giao dịch',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'Ví',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Báo cáo',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Cài đặt',
          ),
        ],
      ),
    );
  }

  List<Widget> _tabs(FinanceState state) => [
    DashboardTab(state: state),
    TransactionsTab(state: state),
    WalletsTab(state: state),
    ReportsTab(state: state),
    SettingsTab(state: state),
  ];

  Future<void> _showAddTransaction(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AddTransactionSheet(),
    );
  }
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet();

  @override
  ConsumerState<_AddTransactionSheet> createState() =>
      _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  var _type = TransactionType.expense;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref
        .watch(financeControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final walletId = state?.wallets.firstOrNull?.id ?? 'cash';
    final categories =
        state?.categories.where((item) => item.type == _type).toList() ??
        const <FinanceCategory>[];
    final categoryId =
        categories.firstOrNull?.id ??
        (_type == TransactionType.income ? 'salary' : 'food');
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Thêm giao dịch', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          SegmentedButton<TransactionType>(
            segments: const [
              ButtonSegment(value: TransactionType.expense, label: Text('Chi')),
              ButtonSegment(value: TransactionType.income, label: Text('Thu')),
            ],
            selected: {_type},
            onSelectionChanged: (value) => setState(() => _type = value.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Số tiền'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Ghi chú'),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () async {
                final error = await ref
                    .read(financeControllerProvider.notifier)
                    .addExpenseFromForm(
                      amountInput: _amount.text,
                      note: _note.text,
                      walletId: walletId,
                      categoryId: categoryId,
                      type: _type,
                    );
                if (!context.mounted) return;
                if (error == null) {
                  Navigator.pop(context);
                  return;
                }
                setState(() => _error = error);
              },
              child: const Text('Lưu giao dịch'),
            ),
          ),
        ],
      ),
    );
  }
}
