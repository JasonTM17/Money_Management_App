import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class PrivacyLockService {
  PrivacyLockService({
    FlutterSecureStorage? storage,
    LocalAuthentication? localAuth,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _localAuth = localAuth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _pinHashKey = 'pin_hash';
  static const _pinSaltKey = 'pin_salt';
  static const _pinKdfVersionKey = 'pin_kdf_version';
  static const _pinFailedCountKey = 'pin_failed_count';
  static const _pinLockUntilKey = 'pin_lock_until';
  static const _biometricEnabledKey = 'biometric_enabled';
  static const _pinKdfVersion = 'pbkdf2-v1';
  static const _pinKdfIterations = 120000;
  static const _maxFailedPinAttempts = 5;
  static const _pinCooldown = Duration(minutes: 5);

  Future<bool> get hasPin async =>
      (await _storage.read(key: _pinHashKey)) != null;

  Future<bool> get isBiometricEnabled async =>
      (await _storage.read(key: _biometricEnabledKey)) == 'true';

  Future<bool> get canUseBiometrics async {
    try {
      if (!await _localAuth.canCheckBiometrics) return false;
      return (await _localAuth.getAvailableBiometrics()).isNotEmpty;
    } on Object {
      return false;
    }
  }

  Future<void> savePin(String pin) async {
    _validatePin(pin);
    final salt = _randomSalt();
    await _storage.write(key: _pinSaltKey, value: salt);
    await _storage.write(key: _pinHashKey, value: _hash(pin, salt));
    await _storage.write(key: _pinKdfVersionKey, value: _pinKdfVersion);
    await _clearFailedAttempts();
  }

  Future<bool> verifyPin(String pin) async {
    await _throwIfLocked();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      await _recordFailedAttempt();
      return false;
    }
    final salt = await _storage.read(key: _pinSaltKey);
    final stored = await _storage.read(key: _pinHashKey);
    if (salt == null || stored == null) return false;
    final version = await _storage.read(key: _pinKdfVersionKey);
    final verified = version == _pinKdfVersion
        ? _constantTimeEquals(_hash(pin, salt), stored)
        : _constantTimeEquals(_legacyHash(pin, salt), stored);
    if (!verified) {
      await _recordFailedAttempt();
      return false;
    }
    if (version != _pinKdfVersion) await savePin(pin);
    await _clearFailedAttempts();
    return true;
  }

  Future<bool> authenticateBiometric({required String localizedReason}) async {
    if (!await isBiometricEnabled) return false;
    final authenticated = await _authenticateWithBiometric(
      localizedReason: localizedReason,
    );
    if (authenticated) await _clearFailedAttempts();
    return authenticated;
  }

  Future<bool> enableBiometric({required String localizedReason}) async {
    final authenticated = await _authenticateWithBiometric(
      localizedReason: localizedReason,
    );
    if (!authenticated) return false;
    await _storage.write(key: _biometricEnabledKey, value: 'true');
    await _clearFailedAttempts();
    return true;
  }

  Future<void> disableBiometric() async {
    await _storage.write(key: _biometricEnabledKey, value: 'false');
  }

  Future<bool> _authenticateWithBiometric({
    required String localizedReason,
  }) async {
    if (!await canUseBiometrics) return false;
    return _localAuth.authenticate(
      localizedReason: localizedReason,
      biometricOnly: true,
    );
  }

  Future<void> _throwIfLocked() async {
    final rawUntil = await _storage.read(key: _pinLockUntilKey);
    if (rawUntil == null) return;
    final lockUntil = DateTime.tryParse(rawUntil);
    if (lockUntil == null || !DateTime.now().isBefore(lockUntil)) {
      await _clearFailedAttempts();
      return;
    }
    throw const FormatException('pinCooldownActive');
  }

  Future<void> _recordFailedAttempt() async {
    final current =
        int.tryParse(await _storage.read(key: _pinFailedCountKey) ?? '') ?? 0;
    final next = current + 1;
    await _storage.write(key: _pinFailedCountKey, value: next.toString());
    if (next >= _maxFailedPinAttempts) {
      await _storage.write(
        key: _pinLockUntilKey,
        value: DateTime.now().add(_pinCooldown).toUtc().toIso8601String(),
      );
    }
  }

  Future<void> _clearFailedAttempts() async {
    await _storage.delete(key: _pinFailedCountKey);
    await _storage.delete(key: _pinLockUntilKey);
  }

  void _validatePin(String pin) {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const FormatException('pinLengthInvalid');
    }
  }

  String _randomSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(values);
  }

  String _hash(String pin, String salt) {
    final saltBytes = base64Url.decode(salt);
    final digest = _pbkdf2(
      password: utf8.encode(pin),
      salt: saltBytes,
      iterations: _pinKdfIterations,
      length: 32,
    );
    return base64UrlEncode(digest);
  }

  String _legacyHash(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }

  List<int> _pbkdf2({
    required List<int> password,
    required List<int> salt,
    required int iterations,
    required int length,
  }) {
    final hmac = Hmac(sha256, password);
    final output = BytesBuilder(copy: false);
    var blockIndex = 1;
    while (output.length < length) {
      final indexBytes = ByteData(4)..setUint32(0, blockIndex);
      var block = hmac.convert([
        ...salt,
        ...indexBytes.buffer.asUint8List(),
      ]).bytes;
      final result = Uint8List.fromList(block);
      for (var i = 1; i < iterations; i++) {
        block = hmac.convert(block).bytes;
        for (var j = 0; j < result.length; j++) {
          result[j] ^= block[j];
        }
      }
      output.add(result);
      blockIndex++;
    }
    return output.takeBytes().take(length).toList();
  }

  bool _constantTimeEquals(String a, String b) {
    final left = utf8.encode(a);
    final right = utf8.encode(b);
    var diff = left.length ^ right.length;
    for (var i = 0; i < left.length && i < right.length; i++) {
      diff |= left[i] ^ right[i];
    }
    return diff == 0;
  }
}
