import 'dart:async';

import 'package:cashflow_manager/features/auth/privacy_gate.dart';
import 'package:cashflow_manager/features/home/finance_controller.dart';
import 'package:cashflow_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test_app_fakes.dart';

class DelayedVerifyPrivacyLockService extends FakePrivacyLockService {
  DelayedVerifyPrivacyLockService({required super.initialPin});

  final _verifyCompleter = Completer<void>();
  String? _pendingPin;

  @override
  Future<bool> verifyPin(String pin) async {
    verifyCount++;
    _pendingPin = pin;
    await _verifyCompleter.future;
    return _pendingPin == initialPin;
  }

  void completeVerify() {
    if (!_verifyCompleter.isCompleted) {
      _verifyCompleter.complete();
    }
  }
}

class QueuedVerifyPrivacyLockService extends FakePrivacyLockService {
  QueuedVerifyPrivacyLockService({required super.initialPin});

  final _verifyCompleters = <Completer<void>>[];

  @override
  Future<bool> verifyPin(String pin) async {
    verifyCount++;
    final completer = Completer<void>();
    _verifyCompleters.add(completer);
    await completer.future;
    return pin == initialPin;
  }

  void completeVerifyAt(int index) {
    final completer = _verifyCompleters[index];
    if (!completer.isCompleted) {
      completer.complete();
    }
  }
}

class DelayedSavePrivacyLockService extends FakePrivacyLockService {
  final _saveCompleter = Completer<void>();
  String? _pendingPin;

  @override
  Future<void> savePin(String pin) async {
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      throw const FormatException('PIN phải có 4-6 chữ số');
    }
    _pendingPin = pin;
    await _saveCompleter.future;
    initialPin = _pendingPin;
  }

  void completeSave() {
    if (!_saveCompleter.isCompleted) {
      _saveCompleter.complete();
    }
  }
}

Future<void> unlockWithPin(WidgetTester tester, String pin) async {
  await tester.enterText(find.widgetWithText(TextField, 'PIN'), pin);
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();
}

Future<void> usePhoneSurface(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScaleFactor = 1,
}) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.devicePixelRatio = 1;
  tester.binding.platformDispatcher.textScaleFactorTestValue = textScaleFactor;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
    tester.binding.platformDispatcher.clearTextScaleFactorTestValue();
  });
}

Future<void> pumpCashFlowApp(
  WidgetTester tester, {
  FakeFinanceStore? store,
  FakePrivacyLockService? privacy,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        financeStoreProvider.overrideWithValue(store ?? FakeFinanceStore()),
        privacyLockBypassProvider.overrideWithValue(privacy == null),
        if (privacy != null)
          privacyLockServiceProvider.overrideWithValue(privacy),
      ],
      child: const CashFlowManagerApp(),
    ),
  );
  await tester.pumpAndSettle();
}
