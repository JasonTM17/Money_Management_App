import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/privacy_lock_service.dart';

final privacyLockServiceProvider = Provider<PrivacyLockService>(
  (ref) => PrivacyLockService(),
);

final privacyLockBypassProvider = Provider<bool>((ref) => false);

class PrivacyGate extends ConsumerStatefulWidget {
  const PrivacyGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PrivacyGate> createState() => _PrivacyGateState();
}

class _PrivacyGateState extends ConsumerState<PrivacyGate> {
  final _pin = TextEditingController();
  final _confirmPin = TextEditingController();
  var _isChecking = true;
  var _hasPin = false;
  var _isUnlocked = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLockState();
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirmPin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(privacyLockBypassProvider) || _isUnlocked) {
      return widget.child;
    }
    if (_isChecking) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 48),
            Icon(
              Icons.lock_person,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              _hasPin ? 'Mở khóa CashFlow Manager' : 'Bảo vệ dữ liệu tài chính',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              _hasPin
                  ? 'Nhập PIN để tiếp tục quản lý chi tiêu.'
                  : 'Tạo PIN 4-6 số để khóa dữ liệu thu chi trên thiết bị này.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: _hasPin ? 'PIN' : 'PIN mới',
              ),
            ),
            if (!_hasPin) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _confirmPin,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Nhập lại PIN'),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _hasPin ? _unlockWithPin : _createPin,
              child: Text(_hasPin ? 'Mở khóa' : 'Tạo PIN'),
            ),
            if (_hasPin) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _unlockWithBiometric,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Mở bằng sinh trắc học'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadLockState() async {
    final hasPin = await ref.read(privacyLockServiceProvider).hasPin;
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _isChecking = false;
    });
  }

  Future<void> _createPin() async {
    if (_pin.text != _confirmPin.text) {
      setState(() => _error = 'PIN nhập lại không khớp');
      return;
    }
    try {
      await ref.read(privacyLockServiceProvider).savePin(_pin.text);
      if (!mounted) return;
      setState(() => _isUnlocked = true);
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  Future<void> _unlockWithPin() async {
    final verified = await ref
        .read(privacyLockServiceProvider)
        .verifyPin(_pin.text);
    if (!mounted) return;
    setState(() {
      _isUnlocked = verified;
      _error = verified ? null : 'PIN không đúng';
    });
  }

  Future<void> _unlockWithBiometric() async {
    final verified = await ref
        .read(privacyLockServiceProvider)
        .authenticateBiometric();
    if (!mounted) return;
    setState(() {
      _isUnlocked = verified;
      _error = verified ? null : 'Không thể xác thực sinh trắc học';
    });
  }
}
