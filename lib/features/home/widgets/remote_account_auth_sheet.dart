import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../account/remote_account_controller.dart';

class RemoteAccountAuthSheet extends ConsumerStatefulWidget {
  const RemoteAccountAuthSheet({super.key});

  @override
  ConsumerState<RemoteAccountAuthSheet> createState() =>
      _RemoteAccountAuthSheetState();
}

class _RemoteAccountAuthSheetState
    extends ConsumerState<RemoteAccountAuthSheet> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.t('accountSync'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('remote-account-email-field'),
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: l10n.t('email')),
            ),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('remote-account-password-field'),
              controller: _passwordController,
              obscureText: true,
              decoration: InputDecoration(labelText: l10n.t('password')),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const ValueKey('remote-account-login-button'),
                  onPressed: _login,
                  icon: const Icon(Icons.login),
                  label: Text(l10n.t('login')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('remote-account-register-button'),
                  onPressed: _register,
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.t('register')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() => ref
      .read(remoteAccountControllerProvider.notifier)
      .login(email: _emailController.text, password: _passwordController.text);

  Future<void> _register() => ref
      .read(remoteAccountControllerProvider.notifier)
      .register(
        email: _emailController.text,
        password: _passwordController.text,
      );
}
