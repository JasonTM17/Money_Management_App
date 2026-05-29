import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../finance_controller.dart';

class BackupRestoreSheet extends ConsumerStatefulWidget {
  const BackupRestoreSheet({super.key});

  @override
  ConsumerState<BackupRestoreSheet> createState() => _BackupRestoreSheetState();
}

class _BackupRestoreSheetState extends ConsumerState<BackupRestoreSheet> {
  var _busy = false;
  String? _message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          MediaQuery.of(context).viewInsets.bottom + 20,
        ),
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
              'Backup / restore dữ liệu',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Xuất file JSON offline hoặc khôi phục dữ liệu từ file backup CashFlow Manager.',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _exportBackup,
              icon: const Icon(Icons.ios_share),
              label: const Text('Xuất backup JSON'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _busy ? null : _restoreBackup,
              icon: const Icon(Icons.restore),
              label: const Text('Khôi phục từ file JSON'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
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
      setState(() => _message = 'Đã tạo file backup JSON.');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Không xuất được backup: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
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
        throw const FormatException('Không đọc được file backup');
      }
      final error = await ref
          .read(financeControllerProvider.notifier)
          .restoreBackup(utf8.decode(bytes));
      if (!mounted) return;
      setState(() {
        _message = error ?? 'Đã khôi phục dữ liệu thành công.';
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Không khôi phục được: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
