import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../../core/finance_models.dart';
import '../finance_controller.dart';
import 'home_common_widgets.dart';

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
  var _isSubmitting = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheetScaffold(
      children: [
        SheetTitle(
          title: widget.goal == null ? l10n.t('addGoal') : l10n.t('updateGoal'),
          icon: Icons.savings,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _name,
          decoration: InputDecoration(labelText: l10n.t('goalName')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _target,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.t('goalTargetAmount')),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _saved,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(labelText: l10n.t('goalSavedAmount')),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _pickDeadline,
          icon: const Icon(Icons.event_available),
          label: Text(l10n.deadline(_deadline)),
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
          onPressed: _isSubmitting ? null : _save,
          child: Text(
            widget.goal == null ? l10n.t('saveGoal') : l10n.t('updateGoal'),
          ),
        ),
      ],
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
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
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
    setState(() {
      _isSubmitting = false;
      _error = context.l10n.error(error);
    });
  }
}
