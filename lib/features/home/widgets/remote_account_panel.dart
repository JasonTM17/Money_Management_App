import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../account/remote_account_controller.dart';
import 'home_common_widgets.dart';
import 'remote_account_auth_sheet.dart';

class RemoteAccountPanel extends ConsumerWidget {
  const RemoteAccountPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(remoteAccountControllerProvider);
    final l10n = context.l10n;
    return SoftPanel(
      key: const ValueKey('remote-account-panel'),
      padding: const EdgeInsets.all(12),
      child: account.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => _StatusLine(
          icon: Icons.cloud_off,
          title: l10n.t('syncServerUnavailable'),
        ),
        data: (state) => state.isSignedIn
            ? _SignedInPanel(state: state)
            : _SignedOutPanel(onOpen: () => _showAuthSheet(context)),
      ),
    );
  }

  Future<void> _showAuthSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const RemoteAccountAuthSheet(),
    );
  }
}

class _SignedOutPanel extends StatelessWidget {
  const _SignedOutPanel({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusLine(
          icon: Icons.cloud_queue,
          title: l10n.t('accountSync'),
          subtitle: l10n.t('accountSyncSignedOut'),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const ValueKey('remote-account-open-auth-button'),
          onPressed: onOpen,
          icon: const Icon(Icons.login),
          label: Text(l10n.t('login')),
        ),
      ],
    );
  }
}

class _SignedInPanel extends ConsumerWidget {
  const _SignedInPanel({required this.state});

  final RemoteAccountState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final session = state.session!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _StatusLine(
          icon: state.premium ? Icons.workspace_premium : Icons.cloud_done,
          title: session.email,
          subtitle: state.premium
              ? l10n.t('premiumActive')
              : l10n.t('premiumLocked'),
        ),
        if (state.messageKey != null) ...[
          const SizedBox(height: 8),
          Text(
            l10n.t(state.messageKey!),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              key: const ValueKey('remote-account-refresh-button'),
              onPressed: () => ref
                  .read(remoteAccountControllerProvider.notifier)
                  .refreshEntitlements(),
              icon: const Icon(Icons.sync),
              label: Text(l10n.t('syncNow')),
            ),
            OutlinedButton.icon(
              key: const ValueKey('remote-account-logout-button'),
              onPressed: () =>
                  ref.read(remoteAccountControllerProvider.notifier).logout(),
              icon: const Icon(Icons.logout),
              label: Text(l10n.t('logout')),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({required this.icon, required this.title, this.subtitle});

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              if (subtitle != null) Text(subtitle!),
            ],
          ),
        ),
      ],
    );
  }
}
