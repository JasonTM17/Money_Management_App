import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final transactions = _filteredTransactions(categoryById);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SectionTitle('Giao dịch'),
        TextField(
          controller: _search,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            labelText: 'Tìm theo ghi chú hoặc danh mục',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 12),
        SegmentedButton<TransactionType?>(
          segments: const [
            ButtonSegment(value: null, label: Text('Tất cả')),
            ButtonSegment(value: TransactionType.expense, label: Text('Chi')),
            ButtonSegment(value: TransactionType.income, label: Text('Thu')),
          ],
          selected: {_filter},
          onSelectionChanged: (value) => setState(() => _filter = value.first),
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          const EmptyState(message: 'Không có giao dịch phù hợp'),
        ...transactions.map(
          (item) => TransactionTile(
            transaction: item,
            categoryLabel: categoryById[item.categoryId]?.name,
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
      final matchesType = _filter == null || item.type == _filter;
      final matchesQuery =
          query.isEmpty ||
          item.note.toLowerCase().contains(query) ||
          item.categoryId.toLowerCase().contains(query) ||
          (category?.name.toLowerCase().contains(query) ?? false);
      return matchesType && matchesQuery;
    }).toList();
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
        title: const Text('Xóa giao dịch?'),
        content: Text(
          transaction.note.isEmpty ? transaction.categoryId : transaction.note,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
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
