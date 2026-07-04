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
        ? AppTheme.incomeGreen
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
      padding: const EdgeInsets.only(bottom: 8),
      child: SoftPanel(
        tint: color,
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(
                isIncome
                    ? Icons.arrow_downward
                    : isTransfer
                    ? Icons.swap_horiz
                    : Icons.arrow_upward,
                color: color,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.18,
                              ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 108),
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
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: color,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
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
            if (onDelete != null) ...[
              const SizedBox(width: 4),
              SizedBox.square(
                dimension: 32,
                child: IconButton(
                  tooltip: context.l10n.t('deleteTransaction'),
                  icon: const Icon(Icons.delete_outline),
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 32,
                    height: 32,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                ),
              ),
            ],
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(8),
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
