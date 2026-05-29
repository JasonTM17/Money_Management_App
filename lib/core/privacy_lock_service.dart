import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PrivacyLockService {
  PrivacyLockService({FlutterSecureStorage? storage, LocalAuthentication? localAuth})
    : _storage = storage ?? const FlutterSecureStorage(),
      _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _pinHashKey = 'pin_hash';
  static const _pinSaltKey = 'pin_salt';

  Future<bool> get hasPin async => (await _storage.read(key: _pinHashKey)) != null;

  Future<void> savePin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const FormatException('PIN phải có 4-6 chữ số');
    }
    final salt = _randomSalt();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _hash(pin, salt));
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSaltKey);
    final stored = await _storage.read(key: _pinHashKey);
    if (salt == null || stored == null) return false;
    return _hash(pin, salt) == stored;
  }

  Future<bool> authenticateBiometric() async {
    final available = (await _localAuth.canCheckBiometrics) || (await _localAuth.isDeviceSupported());
    if (!available) return false;
    return _localAuth.authenticate(localizedReason: 'Mở khóa CashFlow Manager');
  }

  String _randomSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  String _hash(String pin, String salt) => sha256.convert(utf8.encode('$salt:$pin')).toString();
}
