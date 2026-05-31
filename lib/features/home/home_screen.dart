import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_localizations.dart';
import '../../data/local_finance_store.dart';
import 'finance_controller.dart';
import 'home_widgets.dart';
import 'widgets/transaction_form_sheet.dart';

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
    final currentState = finance.maybeWhen(
      data: (state) => state,
      orElse: () => null,
    );
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF16A34A), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.24),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(Icons.savings, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Text('CashFlow Manager'),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('settings-action-button'),
            tooltip: l10n.t('settings'),
            onPressed: currentState == null
                ? null
                : () => _showSettings(context, currentState),
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: finance.when(
        data: (state) => DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colorScheme.primary.withValues(alpha: isDark ? 0.12 : 0.08),
                colorScheme.surface,
                colorScheme.secondary.withValues(alpha: isDark ? 0.10 : 0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: _tabs(state)[_index],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text(l10n.t('loadDataFailed'))),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransaction(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('addTransaction')),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 28,
                      offset: const Offset(0, 14),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (value) => setState(() => _index = value),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard),
                  label: l10n.t('dashboard'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.receipt_long_outlined),
                  selectedIcon: const Icon(Icons.receipt_long),
                  label: l10n.t('transactions'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.account_balance_wallet_outlined),
                  selectedIcon: const Icon(Icons.account_balance_wallet),
                  label: l10n.t('wallets'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.savings_outlined),
                  selectedIcon: const Icon(Icons.savings),
                  label: l10n.t('budgets'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.pie_chart_outline),
                  selectedIcon: const Icon(Icons.pie_chart),
                  label: l10n.t('reports'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _tabs(FinanceState state) => [
    DashboardTab(state: state),
    TransactionsTab(state: state),
    WalletsTab(state: state),
    BudgetsTab(state: state),
    ReportsTab(state: state),
  ];

  Future<void> _showSettings(BuildContext context, FinanceState state) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(context.l10n.t('settings'))),
          body: SettingsTab(state: state),
        ),
      ),
    );
  }

  Future<void> _showAddTransaction(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const TransactionFormSheet(),
    );
  }
}
