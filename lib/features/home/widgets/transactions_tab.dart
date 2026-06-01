import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../../core/finance_models.dart';
import '../../../data/local_finance_store.dart';
import '../finance_controller.dart';
import 'home_common_widgets.dart';
import 'transaction_form_sheet.dart';

class TransactionsTab extends ConsumerStatefulWidget {
  const TransactionsTab({super.key, required this.state});

  final FinanceState state;

  @override
  ConsumerState<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends ConsumerState<TransactionsTab> {
  final _search = TextEditingController();
  TransactionType? _filter;
  String? _walletFilterId;
  String? _categoryFilterId;
  DateTime? _monthFilter;

  @override
  void didUpdateWidget(covariant TransactionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final walletExists = widget.state.wallets.any(
      (wallet) => wallet.id == _walletFilterId,
    );
    final categoryExists = widget.state.categories.any(
      (category) => category.id == _categoryFilterId,
    );
    final monthExists = _transactionMonths().any(
      (month) =>
          month.year == _monthFilter?.year &&
          month.month == _monthFilter?.month,
    );
    if ((_walletFilterId != null && !walletExists) ||
        (_categoryFilterId != null && !categoryExists) ||
        (_monthFilter != null && !monthExists)) {
      _walletFilterId = walletExists ? _walletFilterId : null;
      _categoryFilterId = categoryExists ? _categoryFilterId : null;
      _monthFilter = monthExists ? _monthFilter : null;
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoryById = {
      for (final category in widget.state.categories) category.id: category,
    };
    final walletById = {
      for (final wallet in widget.state.wallets) wallet.id: wallet,
    };
    final transactions = _filteredTransactions(categoryById);
    final l10n = context.l10n;
    final monthOptions = _transactionMonths();
    final walletFilterValue =
        widget.state.wallets.any((wallet) => wallet.id == _walletFilterId)
        ? _walletFilterId
        : null;
    final categoryFilterValue =
        widget.state.categories.any(
          (category) => category.id == _categoryFilterId,
        )
        ? _categoryFilterId
        : null;
    final monthFilterValue =
        monthOptions.any(
          (month) =>
              month.year == _monthFilter?.year &&
              month.month == _monthFilter?.month,
        )
        ? _monthFilter
        : null;
    return AppScrollView(
      children: [
        AppSectionHeader(title: l10n.t('transactions')),
        SoftPanel(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const ValueKey('transaction-search-field'),
                controller: _search,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText: l10n.t('searchTransactions'),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              SegmentedButton<TransactionType?>(
                segments: [
                  ButtonSegment(value: null, label: Text(l10n.t('all'))),
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text(l10n.t('expense')),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text(l10n.t('income')),
                  ),
                ],
                selected: {_filter},
                onSelectionChanged: (value) =>
                    setState(() => _filter = value.first),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final fieldWidth = constraints.maxWidth >= 560
                      ? (constraints.maxWidth - 20) / 3
                      : constraints.maxWidth >= 300
                      ? (constraints.maxWidth - 10) / 2
                      : constraints.maxWidth;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: fieldWidth,
                        child: _FilterField(
                          label: l10n.t('wallets'),
                          child: DropdownButtonFormField<String?>(
                            initialValue: walletFilterValue,
                            isExpanded: true,
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.t('allWallets')),
                              ),
                              ...widget.state.wallets.map(
                                (wallet) => DropdownMenuItem(
                                  value: wallet.id,
                                  child: Text(wallet.name),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _walletFilterId = value),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _FilterField(
                          label: l10n.t('category'),
                          child: DropdownButtonFormField<String?>(
                            initialValue: categoryFilterValue,
                            isExpanded: true,
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.t('allCategories')),
                              ),
                              ...widget.state.categories
                                  .where(
                                    (category) =>
                                        category.type !=
                                        TransactionType.transfer,
                                  )
                                  .map(
                                    (category) => DropdownMenuItem(
                                      value: category.id,
                                      child: Text(category.name),
                                    ),
                                  ),
                            ],
                            onChanged: (value) =>
                                setState(() => _categoryFilterId = value),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: fieldWidth,
                        child: _FilterField(
                          label: l10n.t('monthFilter'),
                          child: DropdownButtonFormField<DateTime?>(
                            initialValue: monthFilterValue,
                            isExpanded: true,
                            decoration: const InputDecoration(),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(l10n.t('allMonths')),
                              ),
                              ...monthOptions.map(
                                (month) => DropdownMenuItem(
                                  value: month,
                                  child: Text(l10n.monthYear(month)),
                                ),
                              ),
                            ],
                            onChanged: (value) =>
                                setState(() => _monthFilter = value),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (transactions.isEmpty)
          EmptyState(message: l10n.t('transactionSearchEmpty')),
        ...transactions.map(
          (item) => TransactionTile(
            transaction: item,
            categoryLabel: categoryById[item.categoryId]?.name,
            walletLabel: walletById[item.walletId]?.name,
            onTap: item.type == TransactionType.transfer
                ? null
                : () => _showEditSheet(item),
            onDelete: () => _confirmDelete(item),
          ),
        ),
      ],
    );
  }

  List<FinanceTransaction> _filteredTransactions(
    Map<String, FinanceCategory> categoryById,
  ) {
    final query = _search.text.trim().toLowerCase();
    return widget.state.transactions.where((item) {
      final category = categoryById[item.categoryId];
      final month = _monthFilter;
      final matchesType = _filter == null || item.type == _filter;
      final matchesWallet =
          _walletFilterId == null || item.walletId == _walletFilterId;
      final matchesCategory =
          _categoryFilterId == null || item.categoryId == _categoryFilterId;
      final matchesMonth =
          month == null ||
          (item.date.year == month.year && item.date.month == month.month);
      final matchesQuery =
          query.isEmpty ||
          item.note.toLowerCase().contains(query) ||
          item.categoryId.toLowerCase().contains(query) ||
          (category?.name.toLowerCase().contains(query) ?? false);
      return matchesType &&
          matchesWallet &&
          matchesCategory &&
          matchesMonth &&
          matchesQuery;
    }).toList();
  }

  List<DateTime> _transactionMonths() {
    final months = <DateTime>{
      for (final item in widget.state.transactions)
        DateTime(item.date.year, item.date.month),
    }.toList();
    months.sort((a, b) => b.compareTo(a));
    return months;
  }

  Future<void> _showEditSheet(FinanceTransaction transaction) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TransactionFormSheet(transaction: transaction),
    );
  }

  Future<void> _confirmDelete(FinanceTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('deleteTransactionQuestion')),
        content: Text(
          transaction.note.isEmpty ? transaction.categoryId : transaction.note,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.t('delete')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref
        .read(financeControllerProvider.notifier)
        .deleteTransaction(transaction.id);
  }
}

class _FilterField extends StatelessWidget {
  const _FilterField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        child,
      ],
    );
  }
}
