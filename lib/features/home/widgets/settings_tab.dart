import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../auth/privacy_gate.dart';
import '../../../core/finance_calculator.dart';
import '../../../core/money.dart';
import '../../../data/local_finance_store.dart';
import '../../../app/app_theme.dart';
import '../finance_controller.dart';
import 'backup_restore_sheet.dart';
import 'home_common_widgets.dart';
import 'privacy_security_panel.dart';
import 'remote_account_panel.dart';

class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key, required this.state});

  final FinanceState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref
        .watch(themeModeControllerProvider)
        .maybeWhen(data: (mode) => mode, orElse: () => ThemeMode.system);
    final locale = ref
        .watch(localeControllerProvider)
        .maybeWhen(data: (locale) => locale, orElse: () => const Locale('vi'));
    final l10n = context.l10n;
    final forecast = const FinanceCalculator().forecastEndBalance(
      currentBalance: state.summary.totalBalance,
      recurringTransactions: state.transactions,
      until: DateTime(DateTime.now().year, DateTime.now().month + 1, 1),
      now: DateTime.now(),
    );
    return AppScrollView(
      children: [
        AppSectionHeader(title: l10n.t('futureCashflow')),
        MetricCard(
          title: l10n.t('forecastNextMonthEnd'),
          value: Money(forecast).formatVnd(),
          icon: Icons.calendar_month,
          color: Colors.teal,
        ),
        AppSectionHeader(title: l10n.t('settings')),
        const PrivacySecurityPanel(),
        const SizedBox(height: 10),
        SoftPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('theme'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              SegmentedButton<ThemeMode>(
                key: const ValueKey('theme-mode-segmented-button'),
                segments: [
                  ButtonSegment(
                    value: ThemeMode.system,
                    label: Text(
                      l10n.t('systemTheme'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ButtonSegment(
                    value: ThemeMode.light,
                    label: Text(
                      l10n.t('themeLight'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ButtonSegment(
                    value: ThemeMode.dark,
                    label: Text(
                      l10n.t('themeDark'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                selected: {themeMode},
                onSelectionChanged: (selection) => ref
                    .read(themeModeControllerProvider.notifier)
                    .setThemeMode(selection.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        InlineInfoCard(
          icon: Icons.currency_exchange,
          title: l10n.t('currency'),
          subtitle: l10n.t('defaultCurrency'),
        ),
        const SizedBox(height: 10),
        SoftPanel(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.t('language'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              SegmentedButton<Locale>(
                key: const ValueKey('locale-segmented-button'),
                segments: [
                  ButtonSegment(
                    value: const Locale('vi'),
                    label: Text(
                      l10n.t('languageVietnamese'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ButtonSegment(
                    value: const Locale('en'),
                    label: Text(
                      l10n.t('languageEnglish'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  ButtonSegment(
                    value: const Locale('ja'),
                    label: Text(
                      l10n.t('languageJapanese'),
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
                selected: {locale},
                onSelectionChanged: (selection) => ref
                    .read(localeControllerProvider.notifier)
                    .setLocale(selection.first),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const RemoteAccountPanel(),
        const SizedBox(height: 10),
        InlineInfoCard(
          key: const ValueKey('backup-restore-card'),
          icon: Icons.backup,
          title: l10n.t('backupRestore'),
          subtitle: l10n.t('backupRestoreSubtitle'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _showBackupRestoreSheet(context),
        ),
        const SizedBox(height: 10),
        InlineInfoCard(
          key: const ValueKey('reset-data-card'),
          icon: Icons.delete_forever,
          title: l10n.t('resetData'),
          subtitle: l10n.t('resetDataSubtitle'),
          color: Theme.of(context).colorScheme.error,
          onTap: () => _confirmResetData(context, ref),
        ),
      ],
    );
  }

  Future<void> _showBackupRestoreSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const BackupRestoreSheet(),
    );
  }

  Future<void> _confirmResetData(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.t('resetDataConfirmTitle')),
        content: Text(context.l10n.t('resetDataWarning')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.t('resetData')),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final authenticated = await confirmSensitiveAction(context, ref);
    if (!authenticated || !context.mounted) return;
    final error = await ref
        .read(financeControllerProvider.notifier)
        .resetData();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? context.l10n.t('resetDataSuccess')
              : context.l10n.error(error),
        ),
      ),
    );
  }
}
