import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_localizations.dart';
import '../../auth/privacy_gate.dart';
import 'home_common_widgets.dart';

class PrivacySecurityPanel extends ConsumerStatefulWidget {
  const PrivacySecurityPanel({super.key});

  @override
  ConsumerState<PrivacySecurityPanel> createState() =>
      _PrivacySecurityPanelState();
}

class _PrivacySecurityPanelState extends ConsumerState<PrivacySecurityPanel> {
  var _hasPin = false;
  var _biometricEnabled = false;
  var _canUseBiometrics = false;
  var _isLoading = true;
  var _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final biometricSubtitle = !_hasPin
        ? l10n.t('biometricRequiresPin')
        : !_canUseBiometrics
        ? l10n.t('biometricUnavailable')
        : _biometricEnabled
        ? l10n.t('biometricUnlockEnabled')
        : l10n.t('biometricUnlockDisabled');
    return SoftPanel(
      key: const ValueKey('privacy-security-panel'),
      tint: colorScheme.primary,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.13),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_person,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.t('privacyLock'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      l10n.t('privacyLockSubtitle'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              StatusPill(
                label: _hasPin
                    ? l10n.t('privacyLockEnabled')
                    : l10n.t('privacyLockDisabled'),
                color: _hasPin ? colorScheme.primary : colorScheme.outline,
                icon: _hasPin ? Icons.check : Icons.lock_open,
              ),
            ],
          ),
          const SoftPanelDivider(),
          SwitchListTile.adaptive(
            key: const ValueKey('biometric-unlock-switch'),
            contentPadding: EdgeInsets.zero,
            secondary: Icon(Icons.fingerprint, color: colorScheme.primary),
            title: Text(
              l10n.t('biometricUnlockSetting'),
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(biometricSubtitle),
            value: _biometricEnabled,
            onChanged:
                _isLoading || _isUpdating || !_hasPin || !_canUseBiometrics
                ? null
                : _setBiometricEnabled,
          ),
        ],
      ),
    );
  }

  Future<void> _loadState() async {
    final service = ref.read(privacyLockServiceProvider);
    final hasPin = await service.hasPin;
    final biometricEnabled = hasPin && await service.isBiometricEnabled;
    final canUseBiometrics = await service.canUseBiometrics;
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _biometricEnabled = biometricEnabled;
      _canUseBiometrics = canUseBiometrics;
      _isLoading = false;
    });
  }

  Future<void> _setBiometricEnabled(bool enabled) async {
    final l10n = context.l10n;
    setState(() => _isUpdating = true);
    final service = ref.read(privacyLockServiceProvider);
    try {
      if (enabled) {
        final saved = await service.enableBiometric(
          localizedReason: l10n.t('biometricEnableReason'),
        );
        if (!mounted) return;
        setState(() {
          _biometricEnabled = saved;
          _isUpdating = false;
        });
        if (!saved) _showSnack(l10n.t('biometricEnableFailed'));
        return;
      }
      await service.disableBiometric();
      if (!mounted) return;
      setState(() {
        _biometricEnabled = false;
        _isUpdating = false;
      });
    } on Object {
      if (!mounted) return;
      setState(() => _isUpdating = false);
      _showSnack(l10n.t('biometricEnableFailed'));
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
