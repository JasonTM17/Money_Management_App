import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/local_finance_store.dart';
import '../finance_controller.dart';

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
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Chuyển tiền giữa ví',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _fromWalletId,
                decoration: const InputDecoration(labelText: 'Ví nguồn'),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem(
                        value: wallet.id,
                        child: Text(wallet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _fromWalletId = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _toWalletId,
                decoration: const InputDecoration(labelText: 'Ví nhận'),
                items: wallets
                    .map(
                      (wallet) => DropdownMenuItem(
                        value: wallet.id,
                        child: Text(wallet.name),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => _toWalletId = value!),
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: wallets.length < 2 ? null : _submit,
                icon: const Icon(Icons.swap_horiz),
                label: const Text('Thực hiện chuyển ví'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submit() async {
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
      setState(() => _error = error);
      return;
    }
    Navigator.pop(context);
  }
}
