import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../../core/finance_models.dart';
import '../finance_controller.dart';
import 'home_common_widgets.dart';

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
  late DateTime _selectedDate = widget.transaction?.date ?? DateTime.now();
  String? _walletId;
  String? _categoryId;
  String? _error;
  var _isSubmitting = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
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
    return AppSheetScaffold(
      children: [
        SheetTitle(
          title: widget.transaction == null
              ? l10n.t('addTransaction')
              : l10n.t('updateTransaction'),
          icon: widget.transaction == null ? Icons.add_card : Icons.edit,
        ),
        const SizedBox(height: 16),
        SegmentedButton<TransactionType>(
          segments: [
            ButtonSegment(
              value: TransactionType.expense,
              label: Text(l10n.t('expense')),
              icon: const Icon(Icons.arrow_upward),
            ),
            ButtonSegment(
              value: TransactionType.income,
              label: Text(l10n.t('income')),
              icon: const Icon(Icons.arrow_downward),
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
          decoration: InputDecoration(
            labelText: l10n.t('expenseWalletCategory'),
          ),
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
          decoration: InputDecoration(labelText: l10n.t('category')),
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
        _DatePickerField(date: _selectedDate, onTap: _pickDate),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.t('amount')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _note,
          decoration: InputDecoration(labelText: l10n.t('note')),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.t('recurringTransaction')),
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
          key: const ValueKey('transaction-submit-button'),
          onPressed: walletId == null || categoryId == null || _isSubmitting
              ? null
              : () => _save(walletId, categoryId),
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.transaction == null
                      ? l10n.t('saveTransaction')
                      : l10n.t('updateTransaction'),
                ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  Future<void> _save(String walletId, String categoryId) async {
    if (_isSubmitting) return;
    final l10n = context.l10n;
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      final controller = ref.read(financeControllerProvider.notifier);
      final transaction = widget.transaction;
      final error = transaction == null
          ? await controller.addExpenseFromForm(
              amountInput: _amount.text,
              note: _note.text,
              walletId: walletId,
              categoryId: categoryId,
              type: _type,
              date: _selectedDate,
              isRecurring: _isRecurring,
            )
          : await controller.updateTransactionFromForm(
              transaction: transaction,
              amountInput: _amount.text,
              note: _note.text,
              walletId: walletId,
              categoryId: categoryId,
              type: _type,
              date: _selectedDate,
              isRecurring: _isRecurring,
            );
      if (!mounted) return;
      if (error == null) {
        Navigator.pop(context);
        return;
      }
      setState(() {
        _error = l10n.error(error);
        _isSubmitting = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _error = l10n.t('transactionSaveFailed');
        _isSubmitting = false;
      });
    }
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      key: const ValueKey('transaction-date-field'),
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: context.l10n.t('date'),
          prefixIcon: const Icon(Icons.calendar_today),
        ),
        child: Text(
          context.l10n.shortDate(date),
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
