import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../../core/finance_models.dart';
import '../finance_controller.dart';
import 'home_common_widgets.dart';

class BudgetFormSheet extends ConsumerStatefulWidget {
  const BudgetFormSheet({super.key, this.budget});

  final Budget? budget;

  @override
  ConsumerState<BudgetFormSheet> createState() => _BudgetFormSheetState();
}

class _BudgetFormSheetState extends ConsumerState<BudgetFormSheet> {
  late final _limit = TextEditingController(
    text: widget.budget?.limitAmount.toString() ?? '',
  );
  late DateTime _month = widget.budget?.month ?? DateTime.now();
  String? _categoryId;
  String? _error;
  var _isSubmitting = false;

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final state = ref
        .watch(financeControllerProvider)
        .maybeWhen(data: (value) => value, orElse: () => null);
    final categories =
        state?.categories
            .where((item) => item.type == TransactionType.expense)
            .toList() ??
        const <FinanceCategory>[];
    final categoryId =
        _categoryId ?? widget.budget?.categoryId ?? categories.firstOrNull?.id;
    return AppSheetScaffold(
      children: [
        SheetTitle(
          title: widget.budget == null
              ? l10n.t('addBudget')
              : l10n.t('updateBudget'),
          icon: Icons.add_chart,
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: categories.any((item) => item.id == categoryId)
              ? categoryId
              : null,
          decoration: InputDecoration(labelText: l10n.t('categoryExpense')),
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
          controller: _limit,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.t('monthlyLimit')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickMonth,
          icon: const Icon(Icons.calendar_month),
          label: Text(l10n.monthYear(_month)),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 12),
        FilledButton(
          onPressed: categoryId == null || _isSubmitting
              ? null
              : () => _save(categoryId),
          child: Text(
            widget.budget == null
                ? l10n.t('saveBudget')
                : l10n.t('updateBudget'),
          ),
        ),
      ],
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null && mounted) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  Future<void> _save(String categoryId) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    final error = await ref
        .read(financeControllerProvider.notifier)
        .upsertBudgetFromForm(
          budget: widget.budget,
          categoryId: categoryId,
          limitAmountInput: _limit.text,
          month: _month,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _isSubmitting = false;
      _error = context.l10n.error(error);
    });
  }
}
