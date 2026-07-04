import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../app/shimmer_loading.dart';
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
    final compactNavigation = MediaQuery.sizeOf(context).width < 430;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        toolbarHeight: 64,
        title: Row(
          children: [
            Semantics(
              label: 'CashFlow Manager logo',
              image: true,
              child: Image.asset(
                'assets/brand/cashflow-logo-mark.png',
                width: 34,
                height: 34,
                filterQuality: FilterQuality.high,
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Text(
                'CashFlow Manager',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('add-transaction-action-button'),
            tooltip: l10n.t('addTransaction'),
            onPressed: () => _showAddTransaction(context),
            style: IconButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            key: const ValueKey('settings-action-button'),
            tooltip: l10n.t('settings'),
            onPressed: currentState == null
                ? null
                : () => _showSettings(context, currentState),
            icon: const Icon(Icons.tune),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: finance.when(
        data: (state) => _tabs(state)[_index],
        loading: () => const DashboardShimmer(),
        error: (error, _) => ErrorState(
          message: l10n.t('loadDataFailed'),
          onRetry: () => ref.invalidate(financeControllerProvider),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.surfaceSlate : AppTheme.lightPanel,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: colorScheme.outlineVariant.withValues(
                  alpha: isDark ? 0.32 : 0.84,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? Colors.black : AppTheme.ink).withValues(
                    alpha: isDark ? 0.34 : 0.08,
                  ),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: NavigationBar(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelBehavior: compactNavigation
                    ? NavigationDestinationLabelBehavior.onlyShowSelected
                    : NavigationDestinationLabelBehavior.alwaysShow,
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
