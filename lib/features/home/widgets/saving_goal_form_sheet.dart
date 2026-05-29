import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/finance_models.dart';
import '../finance_controller.dart';

class SavingGoalFormSheet extends ConsumerStatefulWidget {
  const SavingGoalFormSheet({super.key, this.goal});

  final SavingGoal? goal;

  @override
  ConsumerState<SavingGoalFormSheet> createState() =>
      _SavingGoalFormSheetState();
}

class _SavingGoalFormSheetState extends ConsumerState<SavingGoalFormSheet> {
  late final _name = TextEditingController(text: widget.goal?.name ?? '');
  late final _target = TextEditingController(
    text: widget.goal?.targetAmount.toString() ?? '',
  );
  late final _saved = TextEditingController(
    text: widget.goal?.savedAmount.toString() ?? '0',
  );
  late DateTime _deadline =
      widget.goal?.deadline ??
      DateTime(DateTime.now().year, DateTime.now().month + 6, 1);
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              widget.goal == null ? 'Thêm mục tiêu' : 'Sửa mục tiêu',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên mục tiêu'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số tiền mục tiêu'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _saved,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Đã tiết kiệm'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickDeadline,
              icon: const Icon(Icons.event_available),
              label: Text(
                'Deadline ${_deadline.day}/${_deadline.month}/${_deadline.year}',
              ),
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
              onPressed: _save,
              child: Text(
                widget.goal == null ? 'Lưu mục tiêu' : 'Cập nhật mục tiêu',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked != null && mounted) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final error = await ref
        .read(financeControllerProvider.notifier)
        .saveGoalFromForm(
          goal: widget.goal,
          name: _name.text,
          targetInput: _target.text,
          savedInput: _saved.text,
          deadline: _deadline,
        );
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
      return;
    }
    setState(() => _error = error);
  }
}
