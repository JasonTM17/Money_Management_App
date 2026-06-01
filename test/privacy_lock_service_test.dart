import 'dart:convert';

import 'package:cashflow_manager/core/privacy_lock_service.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

const _localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localAuthChannel, null);
  });

  test('saves and verifies PIN with hardened KDF', () async {
    final service = PrivacyLockService();

    await service.savePin('123456');

    expect(await service.hasPin, isTrue);
    expect(await service.verifyPin('123456'), isTrue);
    expect(await service.verifyPin('000000'), isFalse);
  });

  test('rejects invalid PIN values', () async {
    final service = PrivacyLockService();

    await expectLater(service.savePin('abcd'), throwsFormatException);
    await expectLater(service.savePin('123'), throwsFormatException);
    await expectLater(service.savePin('1234567'), throwsFormatException);
  });

  test('migrates legacy SHA-256 PIN hash after successful verify', () async {
    const salt = 'legacy-salt';
    final legacyHash = sha256.convert(utf8.encode('$salt:4321')).toString();
    FlutterSecureStorage.setMockInitialValues({
      'pin_salt': salt,
      'pin_hash': legacyHash,
    });
    const storage = FlutterSecureStorage();
    final service = PrivacyLockService(storage: storage);

    expect(await service.verifyPin('4321'), isTrue);
    expect(await storage.read(key: 'pin_kdf_version'), 'pbkdf2-v1');
    expect(await storage.read(key: 'pin_hash'), isNot(legacyHash));
  });

  test('locks PIN verification after repeated failed attempts', () async {
    final service = PrivacyLockService();

    await service.savePin('1234');
    for (var i = 0; i < 5; i++) {
      expect(await service.verifyPin('0000'), isFalse);
    }

    await expectLater(
      service.verifyPin('1234'),
      throwsA(
        isA<FormatException>().having(
          (error) => error.message,
          'message',
          'pinCooldownActive',
        ),
      ),
    );
  });

  test('successful PIN verification clears previous failed attempts', () async {
    final service = PrivacyLockService();

    await service.savePin('1234');
    expect(await service.verifyPin('0000'), isFalse);
    expect(await service.verifyPin('1234'), isTrue);
    for (var i = 0; i < 4; i++) {
      expect(await service.verifyPin('0000'), isFalse);
    }

    expect(await service.verifyPin('1234'), isTrue);
  });

  test('biometric opt-in defaults to disabled', () async {
    final service = PrivacyLockService();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_localAuthChannel, (_) async {
          throw StateError('local_auth should not be called while disabled');
        });

    expect(await service.isBiometricEnabled, isFalse);
    expect(
      await service.authenticateBiometric(localizedReason: 'Unlock'),
      isFalse,
    );
  });

  test('enables biometric only after successful local auth', () async {
    const storage = FlutterSecureStorage();
    final service = PrivacyLockService(storage: storage);
    _mockLocalAuth(authenticateResult: true);

    expect(
      await service.enableBiometric(localizedReason: 'Enable biometrics'),
      isTrue,
    );

    expect(await service.isBiometricEnabled, isTrue);
    expect(await storage.read(key: 'biometric_enabled'), 'true');
    expect(
      await service.authenticateBiometric(localizedReason: 'Unlock'),
      isTrue,
    );
  });

  test('failed biometric enable leaves opt-in disabled', () async {
    const storage = FlutterSecureStorage();
    final service = PrivacyLockService(storage: storage);
    _mockLocalAuth(authenticateResult: false);

    expect(
      await service.enableBiometric(localizedReason: 'Enable biometrics'),
      isFalse,
    );

    expect(await service.isBiometricEnabled, isFalse);
    expect(await storage.read(key: 'biometric_enabled'), isNull);
  });

  test('successful biometric unlock clears previous failed attempts', () async {
    FlutterSecureStorage.setMockInitialValues({'biometric_enabled': 'true'});
    final service = PrivacyLockService();
    _mockLocalAuth(authenticateResult: true);

    await service.savePin('1234');
    await service.enableBiometric(localizedReason: 'Enable biometrics');
    for (var i = 0; i < 4; i++) {
      expect(await service.verifyPin('0000'), isFalse);
    }

    expect(
      await service.authenticateBiometric(localizedReason: 'Unlock'),
      isTrue,
    );
    for (var i = 0; i < 4; i++) {
      expect(await service.verifyPin('0000'), isFalse);
    }
    expect(await service.verifyPin('1234'), isTrue);
  });
}

void _mockLocalAuth({
  bool canAuthenticate = true,
  required bool authenticateResult,
}) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_localAuthChannel, (methodCall) async {
        return switch (methodCall.method) {
          'getAvailableBiometrics' =>
            canAuthenticate ? <String>['fingerprint'] : <String>[],
          'isDeviceSupported' => canAuthenticate,
          'authenticate' => authenticateResult,
          _ => null,
        };
      });
}
