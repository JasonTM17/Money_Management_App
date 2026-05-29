import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance_models.dart';
import '../finance_controller.dart';

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

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              widget.budget == null ? 'Thêm ngân sách' : 'Sửa ngân sách',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: categories.any((item) => item.id == categoryId)
                  ? categoryId
                  : null,
              decoration: const InputDecoration(labelText: 'Danh mục chi'),
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
              decoration: const InputDecoration(labelText: 'Hạn mức tháng'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickMonth,
              icon: const Icon(Icons.calendar_month),
              label: Text('Tháng ${_month.month}/${_month.year}'),
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
              onPressed: categoryId == null ? null : () => _save(categoryId),
              child: Text(
                widget.budget == null ? 'Lưu ngân sách' : 'Cập nhật ngân sách',
              ),
            ),
          ],
        ),
      ),
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
    setState(() => _error = error);
  }
}
