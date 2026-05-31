import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app_localizations.dart';
import '../../../core/finance_backup_service.dart';
import '../../auth/privacy_gate.dart';
import '../finance_controller.dart';
import 'home_common_widgets.dart';

class BackupRestoreSheet extends ConsumerStatefulWidget {
  const BackupRestoreSheet({super.key});

  @override
  ConsumerState<BackupRestoreSheet> createState() => _BackupRestoreSheetState();
}

class _BackupRestoreSheetState extends ConsumerState<BackupRestoreSheet> {
  static const _maxBackupBytes = 5 * 1024 * 1024;

  var _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppSheetScaffold(
      children: [
        SheetTitle(
          title: l10n.t('backupRestoreData'),
          icon: Icons.backup_outlined,
        ),
        const SizedBox(height: 8),
        Text(l10n.t('backupIntro')),
        const SizedBox(height: 8),
        Text(
          l10n.t('backupSensitiveWarning'),
          style: TextStyle(
            color: Theme.of(context).colorScheme.error,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _busy ? null : _exportBackup,
          icon: const Icon(Icons.ios_share),
          label: Text(l10n.t('exportBackupJson')),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy ? null : _restoreBackup,
          icon: const Icon(Icons.restore),
          label: Text(l10n.t('restoreFromJson')),
        ),
        if (_message != null) ...[const SizedBox(height: 12), Text(_message!)],
      ],
    );
  }

  Future<void> _exportBackup() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final backup = await ref
          .read(financeControllerProvider.notifier)
          .exportBackup();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(utf8.encode(backup), mimeType: 'application/json'),
          ],
          fileNameOverrides: ['cashflow-manager-backup.json'],
        ),
      );
      if (!mounted) return;
      setState(() => _message = l10n.t('backupCreated'));
    } on Object {
      if (!mounted) return;
      setState(() => _message = l10n.t('backupExportFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );
      if (result == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      final bytes = result.files.single.bytes;
      if (bytes == null) {
        throw FormatException(l10n.t('restoreFileReadFailed'));
      }
      if (bytes.length > _maxBackupBytes) {
        throw FormatException(l10n.t('restoreFileTooLarge'));
      }
      final input = utf8.decode(bytes);
      final controller = ref.read(financeControllerProvider.notifier);
      final preview = controller.previewBackup(input);
      if (!mounted) return;
      final confirmed = await _confirmRestore(preview);
      if (!mounted) return;
      if (!confirmed) {
        setState(() => _message = l10n.t('restoreCancelled'));
        return;
      }
      final authenticated = await confirmSensitiveAction(context, ref);
      if (!mounted) return;
      if (!authenticated) {
        setState(() => _message = l10n.t('restoreCancelled'));
        return;
      }
      final error = await controller.restoreBackup(input);
      if (!mounted) return;
      setState(() {
        _message = error == null ? l10n.t('restoreSuccess') : l10n.error(error);
      });
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(
        () => _message = l10n
            .t('restoreFormatFailed')
            .replaceFirst('{message}', l10n.error(error.message)),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _message = l10n.t('restoreFailed'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirmRestore(FinanceBackupPreview preview) async {
    final exportedAt = preview.exportedAt;
    final l10n = context.l10n;
    final exportedCopy = exportedAt == null
        ? l10n.t('restoreExportMissing')
        : 'Export: ${l10n.shortDate(exportedAt.toLocal())}';
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.t('restoreConfirmTitle')),
            content: Text(
              '$exportedCopy\n'
              '${l10n.t('wallets')}: ${preview.walletCount}\n'
              '${l10n.t('transactions')}: ${preview.transactionCount}\n'
              '${l10n.t('budgets')}: ${preview.budgetCount}\n'
              '${l10n.t('goals')}: ${preview.goalCount}\n\n'
              '${l10n.t('restoreReplaceWarning')}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.t('cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.t('restoreConfirm')),
              ),
            ],
          ),
        ) ??
        false;
  }
}
