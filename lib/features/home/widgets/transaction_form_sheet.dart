import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance_models.dart';
import '../finance_controller.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  const TransactionFormSheet({super.key, this.transaction});

  final FinanceTransaction? transaction;

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  late final _amount = TextEditingController(
    text: widget.transaction?.amount.toString() ?? '',
  );
  late final _note = TextEditingController(
    text: widget.transaction?.note ?? '',
  );
  late TransactionType _type =
      widget.transaction?.type == TransactionType.income
      ? TransactionType.income
      : TransactionType.expense;
  late bool _isRecurring = widget.transaction?.isRecurring ?? false;
  String? _walletId;
  String? _categoryId;
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
    final wallets = state?.wallets ?? const <WalletAccount>[];
    final categories =
        state?.categories.where((item) => item.type == _type).toList() ??
        const <FinanceCategory>[];
    final walletId =
        _walletId ?? widget.transaction?.walletId ?? wallets.firstOrNull?.id;
    final categoryId =
        _categoryId ??
        widget.transaction?.categoryId ??
        categories.firstOrNull?.id;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.transaction == null ? 'Thêm giao dịch' : 'Sửa giao dịch',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            SegmentedButton<TransactionType>(
              segments: const [
                ButtonSegment(
                  value: TransactionType.expense,
                  label: Text('Chi'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: TransactionType.income,
                  label: Text('Thu'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() {
                _type = value.first;
                _categoryId = null;
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: walletId,
              decoration: const InputDecoration(labelText: 'Ví / tài khoản'),
              items: wallets
                  .map(
                    (wallet) => DropdownMenuItem(
                      value: wallet.id,
                      child: Text(wallet.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _walletId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: categories.any((item) => item.id == categoryId)
                  ? categoryId
                  : null,
              decoration: const InputDecoration(labelText: 'Danh mục'),
              items: categories
                  .map(
                    (category) => DropdownMenuItem(
                      value: category.id,
                      child: Text(category.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _categoryId = value),
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
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giao dịch lặp lại'),
              value: _isRecurring,
              onChanged: (value) => setState(() => _isRecurring = value),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: walletId == null || categoryId == null
                  ? null
                  : () => _save(walletId, categoryId),
              child: Text(
                widget.transaction == null
                    ? 'Lưu giao dịch'
                    : 'Cập nhật giao dịch',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(String walletId, String categoryId) async {
    final controller = ref.read(financeControllerProvider.notifier);
    final transaction = widget.transaction;
    final error = transaction == null
        ? await controller.addExpenseFromForm(
            amountInput: _amount.text,
            note: _note.text,
            walletId: walletId,
            categoryId: categoryId,
            type: _type,
            isRecurring: _isRecurring,
          )
        : await controller.updateTransactionFromForm(
            transaction: transaction,
            amountInput: _amount.text,
            note: _note.text,
            walletId: walletId,
            categoryId: categoryId,
            type: _type,
            isRecurring: _isRecurring,
          );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _error = error);
  }
}
