import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';
import '../../../app/app_theme.dart';
import '../../../core/finance_models.dart';
import '../../../core/money.dart';
import 'app_panel_widgets.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.categoryLabel,
    this.walletLabel,
    this.onTap,
    this.onDelete,
  });

  final FinanceTransaction transaction;
  final String? categoryLabel;
  final String? walletLabel;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.type == TransactionType.income;
    final isTransfer = transaction.type == TransactionType.transfer;
    final color = isIncome
        ? AppTheme.incomeBlue
        : isTransfer
        ? AppTheme.seed
        : AppTheme.expenseRed;
    final prefix = isIncome
        ? '+'
        : isTransfer
        ? ''
        : '-';
    final title = transaction.note.isEmpty
        ? categoryLabel ?? transaction.categoryId
        : transaction.note;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SoftPanel(
        tint: color,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward
                    : isTransfer
                    ? Icons.swap_horiz
                    : Icons.arrow_upward,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 10),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 122),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                '$prefix${Money(transaction.amount).formatVnd()}',
                                maxLines: 1,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (onDelete != null)
                              IconButton(
                                tooltip: context.l10n.t('deleteTransaction'),
                                icon: const Icon(Icons.delete_outline),
                                onPressed: onDelete,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _MetaChip(label: categoryLabel ?? transaction.categoryId),
                      if (walletLabel != null) _MetaChip(label: walletLabel!),
                      _MetaChip(
                        label: context.l10n.shortDate(transaction.date),
                      ),
                      if (transaction.isRecurring)
                        _MetaChip(
                          label: context.l10n.t('recurringTransaction'),
                          icon: Icons.repeat,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label, this.icon});

  final String label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(AppTheme.pillRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: colorScheme.onSurfaceVariant),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
