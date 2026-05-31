import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../../data/local_finance_store.dart';
import '../finance_controller.dart';
import 'home_common_widgets.dart';

class WalletTransferSheet extends ConsumerStatefulWidget {
  const WalletTransferSheet({super.key, required this.state});

  final FinanceState state;

  @override
  ConsumerState<WalletTransferSheet> createState() =>
      _WalletTransferSheetState();
}

class _WalletTransferSheetState extends ConsumerState<WalletTransferSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  late String _fromWalletId;
  late String _toWalletId;
  String? _error;
  var _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _fromWalletId = widget.state.wallets.first.id;
    _toWalletId = widget.state.wallets.length > 1
        ? widget.state.wallets[1].id
        : widget.state.wallets.first.id;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final wallets = widget.state.wallets;
    final l10n = context.l10n;
    return AppSheetScaffold(
      children: [
        SheetTitle(
          title: l10n.t('transferBetweenWallets'),
          icon: Icons.swap_horiz,
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _fromWalletId,
          decoration: InputDecoration(labelText: l10n.t('walletSource')),
          items: wallets
              .map(
                (wallet) => DropdownMenuItem(
                  value: wallet.id,
                  child: Text(wallet.name),
                ),
              )
              .toList(),
          onChanged: _isSubmitting
              ? null
              : (value) => setState(() => _fromWalletId = value!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _toWalletId,
          decoration: InputDecoration(labelText: l10n.t('walletDestination')),
          items: wallets
              .map(
                (wallet) => DropdownMenuItem(
                  value: wallet.id,
                  child: Text(wallet.name),
                ),
              )
              .toList(),
          onChanged: _isSubmitting
              ? null
              : (value) => setState(() => _toWalletId = value!),
        ),
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
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: wallets.length < 2 || _isSubmitting ? null : _submit,
          icon: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.swap_horiz),
          label: Text(
            _isSubmitting ? l10n.t('transferring') : l10n.t('transferNow'),
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_fromWalletId == _toWalletId) {
      setState(() => _error = context.l10n.t('walletSameTransferError'));
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final l10n = context.l10n;
    final error = await ref
        .read(financeControllerProvider.notifier)
        .transferFromForm(
          amountInput: _amount.text,
          note: _note.text,
          fromWalletId: _fromWalletId,
          toWalletId: _toWalletId,
        );
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _error = l10n.error(error);
        _isSubmitting = false;
      });
      return;
    }
    Navigator.pop(context);
  }
}
