// ignore_for_file: file_names

import 'package:flutter/material.dart';

import '../../../app/app_localizations.dart';

Future<String?> showBackupPassphraseDialog(
  BuildContext context, {
  required bool confirm,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _BackupPassphraseDialog(confirm: confirm),
  );
}

class _BackupPassphraseDialog extends StatefulWidget {
  const _BackupPassphraseDialog({required this.confirm});

  final bool confirm;

  @override
  State<_BackupPassphraseDialog> createState() =>
      _BackupPassphraseDialogState();
}

class _BackupPassphraseDialogState extends State<_BackupPassphraseDialog> {
  final _passphraseController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _errorKey;

  @override
  void dispose() {
    _passphraseController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.t('backupPassphrase')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            key: const ValueKey('backup-passphrase-field'),
            controller: _passphraseController,
            obscureText: true,
            decoration: InputDecoration(labelText: l10n.t('backupPassphrase')),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('backup-passphrase-confirm-field'),
              controller: _confirmController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.t('backupPassphraseConfirm'),
              ),
            ),
          ],
          if (_errorKey != null) ...[
            const SizedBox(height: 10),
            Text(
              l10n.t(_errorKey!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.t('cancel')),
        ),
        FilledButton(onPressed: _submit, child: Text(l10n.t('confirm'))),
      ],
    );
  }

  void _submit() {
    final passphrase = _passphraseController.text;
    if (passphrase.trim().length < 8) {
      setState(() => _errorKey = 'backupPassphraseTooShort');
      return;
    }
    if (widget.confirm && passphrase != _confirmController.text) {
      setState(() => _errorKey = 'backupPassphraseMismatch');
      return;
    }
    Navigator.pop(context, passphrase);
  }
}
