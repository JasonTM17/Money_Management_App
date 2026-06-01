import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_localizations.dart';
import '../../app/app_theme.dart';
import '../../core/privacy_lock_service.dart';

final privacyLockServiceProvider = Provider<PrivacyLockService>(
  (ref) => PrivacyLockService(),
);

final privacyLockBypassProvider = Provider<bool>((ref) => false);

Future<bool> confirmSensitiveAction(BuildContext context, WidgetRef ref) async {
  if (ref.read(privacyLockBypassProvider)) return true;
  final service = ref.read(privacyLockServiceProvider);
  if (!await service.hasPin) return true;
  if (!context.mounted) return false;
  return await showDialog<bool>(
        context: context,
        builder: (context) => _SensitiveActionAuthDialog(service: service),
      ) ??
      false;
}

class _SensitiveActionAuthDialog extends StatefulWidget {
  const _SensitiveActionAuthDialog({required this.service});

  final PrivacyLockService service;

  @override
  State<_SensitiveActionAuthDialog> createState() =>
      _SensitiveActionAuthDialogState();
}

class _SensitiveActionAuthDialogState
    extends State<_SensitiveActionAuthDialog> {
  final _pin = TextEditingController();
  var _isSubmitting = false;
  var _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBiometricState());
  }

  @override
  void dispose() {
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.t('reauthTitle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l10n.t('reauthSubtitle')),
          const SizedBox(height: 16),
          TextField(
            controller: _pin,
            keyboardType: TextInputType.number,
            obscureText: true,
            autofillHints: const [AutofillHints.password],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 6,
            decoration: const InputDecoration(
              labelText: 'PIN',
              counterText: '',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context, false),
          child: Text(l10n.t('cancel')),
        ),
        if (_biometricEnabled)
          OutlinedButton.icon(
            onPressed: _isSubmitting ? null : _unlockWithBiometric,
            icon: const Icon(Icons.fingerprint),
            label: Text(l10n.t('biometricUnlock')),
          ),
        FilledButton(
          onPressed: _isSubmitting ? null : _unlockWithPin,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.t('confirm')),
        ),
      ],
    );
  }

  Future<void> _loadBiometricState() async {
    final enabled = await widget.service.isBiometricEnabled;
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _unlockWithPin() async {
    final l10n = context.l10n;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final verified = await widget.service.verifyPin(_pin.text);
      if (!mounted) return;
      if (verified) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = l10n.t('pinInvalid');
      });
    } on FormatException catch (error) {
      _finishFailedSubmit(l10n.error(error.message));
    } on Object {
      _finishFailedSubmit(l10n.t('pinUnlockFailed'));
    }
  }

  Future<void> _unlockWithBiometric() async {
    final l10n = context.l10n;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final verified = await widget.service.authenticateBiometric(
        localizedReason: l10n.t('reauthTitle'),
      );
      if (!mounted) return;
      if (verified) {
        Navigator.pop(context, true);
        return;
      }
      setState(() {
        _isSubmitting = false;
        _error = l10n.t('biometricFailed');
      });
    } on Object {
      _finishFailedSubmit(l10n.t('biometricFailed'));
    }
  }

  void _finishFailedSubmit(String message) {
    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _error = message;
    });
  }
}

class PrivacyGate extends ConsumerStatefulWidget {
  const PrivacyGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends ConsumerState<PrivacyGate>
    with WidgetsBindingObserver {
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  var _isChecking = true;
  var _hasPin = false;
  var _isUnlocked = false;
  var _isSubmitting = false;
  var _isAppResumed = true;
  var _authAttemptEpoch = 0;
  var _biometricEnabled = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppResumed = state == AppLifecycleState.resumed;
    if (_isAppResumed && _hasPin) {
      unawaited(_loadBiometricPreference());
    }
    if (state
        case AppLifecycleState.inactive ||
            AppLifecycleState.hidden ||
            AppLifecycleState.paused) {
      if (ref.read(privacyLockBypassProvider) || !_hasPin) {
        _invalidateAuthAttempts();
        return;
      }
      _relock();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(privacyLockBypassProvider) || _isUnlocked) {
      return widget.child;
    }
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.primaryContainer,
                        colorScheme.surfaceContainerHighest,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: colorScheme.primary.withValues(
                          alpha: 0.14,
                        ),
                        foregroundColor: colorScheme.primary,
                        child: const Icon(Icons.lock_person, size: 34),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _hasPin
                            ? l10n.t('pinUnlockTitle')
                            : l10n.t('pinCreateTitle'),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _hasPin
                            ? l10n.t('pinUnlockSubtitle')
                            : l10n.t('pinCreateSubtitle'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _pin,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          maxLength: 6,
                          decoration: InputDecoration(
                            labelText: _hasPin ? 'PIN' : l10n.t('pinNew'),
                            counterText: '',
                          ),
                        ),
                        if (!_hasPin) ...[
                          const SizedBox(height: 12),
                          TextField(
                            controller: _confirmPin,
                            keyboardType: TextInputType.number,
                            obscureText: true,
                            autofillHints: const [AutofillHints.password],
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            maxLength: 6,
                            decoration: InputDecoration(
                              labelText: l10n.t('pinConfirm'),
                              counterText: '',
                            ),
                          ),
                        ],
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(color: colorScheme.error),
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isSubmitting
                              ? null
                              : _hasPin
                              ? _unlockWithPin
                              : _createPin,
                          child: _isSubmitting
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _hasPin
                                      ? l10n.t('pinUnlock')
                                      : l10n.t('pinCreate'),
                                ),
                        ),
                        if (_hasPin && _biometricEnabled) ...[
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : _unlockWithBiometric,
                            icon: const Icon(Icons.fingerprint),
                            label: Text(l10n.t('biometricUnlock')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _loadLockState() async {
    final service = ref.read(privacyLockServiceProvider);
    final hasPin = await service.hasPin;
    final biometricEnabled = hasPin && await service.isBiometricEnabled;
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _biometricEnabled = biometricEnabled;
      _isChecking = false;
    });
  }

  Future<void> _loadBiometricPreference() async {
    final enabled =
        _hasPin &&
        await ref.read(privacyLockServiceProvider).isBiometricEnabled;
    if (!mounted) return;
    setState(() => _biometricEnabled = enabled);
  }

  Future<void> _createPin() async {
    if (_isSubmitting) return;
    final l10n = context.l10n;
    if (_pin.text != _confirmPin.text) {
      setState(() => _error = l10n.t('pinMismatch'));
      return;
    }
    final attemptEpoch = _authAttemptEpoch;
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      await ref.read(privacyLockServiceProvider).savePin(_pin.text);
      if (!mounted) return;
      final unlocked = _isCurrentAuthAttempt(attemptEpoch);
      setState(() {
        _hasPin = true;
        _biometricEnabled = false;
        _isUnlocked = unlocked;
        _isSubmitting = false;
        if (!unlocked) {
          _pin.clear();
          _confirmPin.clear();
        }
      });
    } on FormatException catch (error) {
      _finishFailedAuthAttempt(l10n.error(error.message), attemptEpoch);
    } on Object {
      _finishFailedAuthAttempt(l10n.t('pinSaveFailed'), attemptEpoch);
    }
  }

  Future<void> _unlockWithPin() async {
    if (_isSubmitting) return;
    final l10n = context.l10n;
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final attemptEpoch = _authAttemptEpoch;
    try {
      final verified = await ref
          .read(privacyLockServiceProvider)
          .verifyPin(_pin.text);
      _finishUnlockAttempt(
        verified: verified,
        failureMessage: l10n.t('pinInvalid'),
        attemptEpoch: attemptEpoch,
      );
    } on FormatException catch (error) {
      _finishFailedAuthAttempt(l10n.error(error.message), attemptEpoch);
    } on Object {
      _finishFailedAuthAttempt(l10n.t('pinUnlockFailed'), attemptEpoch);
    }
  }

  Future<void> _unlockWithBiometric() async {
    if (_isSubmitting) return;
    final l10n = context.l10n;
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    final attemptEpoch = _authAttemptEpoch;
    try {
      final verified = await ref
          .read(privacyLockServiceProvider)
          .authenticateBiometric(localizedReason: l10n.t('pinUnlockTitle'));
      _finishUnlockAttempt(
        verified: verified,
        failureMessage: l10n.t('biometricFailed'),
        attemptEpoch: attemptEpoch,
      );
    } on Object {
      _finishFailedAuthAttempt(l10n.t('biometricFailed'), attemptEpoch);
    }
  }

  void _finishFailedAuthAttempt(String message, int attemptEpoch) {
    if (!_isCurrentAuthAttempt(attemptEpoch)) return;
    _finishFailedSubmit(message);
  }

  void _finishFailedSubmit(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _isSubmitting = false;
    });
  }

  void _finishUnlockAttempt({
    required bool verified,
    required String failureMessage,
    required int attemptEpoch,
  }) {
    if (!mounted || !_isCurrentAuthAttempt(attemptEpoch)) return;
    setState(() {
      _isUnlocked = verified;
      _error = verified ? null : failureMessage;
      _isSubmitting = false;
    });
  }

  bool _isCurrentAuthAttempt(int attemptEpoch) =>
      _isAppResumed && attemptEpoch == _authAttemptEpoch;

  void _invalidateAuthAttempts() {
    _authAttemptEpoch++;
  }

  void _relock() {
    _invalidateAuthAttempts();
    _pin.clear();
    _confirmPin.clear();
    setState(() {
      _isUnlocked = false;
      _isSubmitting = false;
      _biometricEnabled = false;
      _error = null;
    });
    unawaited(_loadBiometricPreference());
  }
}
