import 'package:cashflow_manager/features/auth/privacy_gate.dart';
import 'package:cashflow_manager/features/home/finance_controller.dart';
import 'package:cashflow_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/finance_widget_test_helpers.dart';
import '../test_app_fakes.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('privacy and authentication', () {
    testWidgets('sets up first-run PIN before showing dashboard', (
      tester,
    ) async {
      await pumpCashFlowApp(tester, privacy: FakePrivacyLockService());

      expect(find.text('Bảo vệ dữ liệu tài chính'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'PIN mới'), '1234');
      await tester.enterText(
        find.widgetWithText(TextField, 'Nhập lại PIN'),
        '1234',
      );
      await tester.tap(find.text('Tạo PIN'));
      await tester.pumpAndSettle();

      expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
    });

    testWidgets('relocks after first-run PIN when app leaves foreground', (
      tester,
    ) async {
      await pumpCashFlowApp(tester, privacy: FakePrivacyLockService());

      await tester.enterText(find.widgetWithText(TextField, 'PIN mới'), '1234');
      await tester.enterText(
        find.widgetWithText(TextField, 'Nhập lại PIN'),
        '1234',
      );
      await tester.tap(find.text('Tạo PIN'));
      await tester.pumpAndSettle();
      expect(find.text('Tổng số dư hiện tại'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
    });

    testWidgets('stays locked when app leaves foreground during PIN save', (
      tester,
    ) async {
      final privacy = DelayedSavePrivacyLockService();
      await pumpCashFlowApp(tester, privacy: privacy);

      await tester.enterText(find.widgetWithText(TextField, 'PIN mới'), '1234');
      await tester.enterText(
        find.widgetWithText(TextField, 'Nhập lại PIN'),
        '1234',
      );
      await tester.tap(find.text('Tạo PIN'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      privacy.completeSave();
      await tester.pumpAndSettle();

      expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
      expect(find.text('Tổng số dư hiện tại'), findsNothing);
    });

    testWidgets('ignores stale first-run PIN save after app resumes', (
      tester,
    ) async {
      final privacy = DelayedSavePrivacyLockService();
      await pumpCashFlowApp(tester, privacy: privacy);

      await tester.enterText(find.widgetWithText(TextField, 'PIN mới'), '1234');
      await tester.enterText(
        find.widgetWithText(TextField, 'Nhập lại PIN'),
        '1234',
      );
      await tester.tap(find.text('Tạo PIN'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      privacy.completeSave();
      await tester.pumpAndSettle();

      expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
      expect(find.text('Tổng số dư hiện tại'), findsNothing);
    });

    testWidgets('unlocks existing PIN before showing dashboard', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeStoreProvider.overrideWithValue(FakeFinanceStore()),
            privacyLockServiceProvider.overrideWithValue(
              FakePrivacyLockService(initialPin: '4321'),
            ),
          ],
          child: const CashFlowManagerApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
      await tester.tap(find.text('Mở khóa'));
      await tester.pumpAndSettle();

      expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
    });

    testWidgets('hides biometric unlock until the user opts in', (
      tester,
    ) async {
      await pumpCashFlowApp(
        tester,
        privacy: FakePrivacyLockService(initialPin: '4321'),
      );

      expect(find.byIcon(Icons.fingerprint), findsNothing);
    });

    testWidgets('settings biometric switch enables unlock after relock', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await usePhoneSurface(tester);
      final privacy = FakePrivacyLockService(initialPin: '4321');
      await pumpCashFlowApp(tester, privacy: privacy);
      await unlockWithPin(tester, '4321');

      await tester.tap(find.byKey(const ValueKey('settings-action-button')));
      await tester.pumpAndSettle();
      final biometricSwitch = find.byKey(
        const ValueKey('biometric-unlock-switch'),
      );
      await tester.scrollUntilVisible(biometricSwitch, 300);
      expect(tester.widget<SwitchListTile>(biometricSwitch).value, isFalse);

      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();

      expect(privacy.biometricEnabled, isTrue);
      expect(tester.widget<SwitchListTile>(biometricSwitch).value, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpCashFlowApp(tester, privacy: privacy);

      expect(biometricSwitch, findsNothing);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
    });

    testWidgets('settings biometric switch disables unlock button', (
      tester,
    ) async {
      addTearDown(
        () => tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        ),
      );
      await usePhoneSurface(tester);
      final privacy = FakePrivacyLockService(
        initialPin: '4321',
        biometricEnabled: true,
      );
      await pumpCashFlowApp(tester, privacy: privacy);
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      await unlockWithPin(tester, '4321');

      await tester.tap(find.byKey(const ValueKey('settings-action-button')));
      await tester.pumpAndSettle();
      final biometricSwitch = find.byKey(
        const ValueKey('biometric-unlock-switch'),
      );
      await tester.scrollUntilVisible(biometricSwitch, 300);
      expect(tester.widget<SwitchListTile>(biometricSwitch).value, isTrue);

      await tester.tap(biometricSwitch);
      await tester.pumpAndSettle();

      expect(privacy.biometricEnabled, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      await pumpCashFlowApp(tester, privacy: privacy);

      expect(biometricSwitch, findsNothing);
      expect(find.byIcon(Icons.fingerprint), findsNothing);
    });

    testWidgets('stays locked when app leaves foreground during PIN unlock', (
      tester,
    ) async {
      final privacy = DelayedVerifyPrivacyLockService(initialPin: '4321');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeStoreProvider.overrideWithValue(FakeFinanceStore()),
            privacyLockServiceProvider.overrideWithValue(privacy),
          ],
          child: const CashFlowManagerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
      await tester.tap(find.text('Mở khóa'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      privacy.completeVerify();
      await tester.pumpAndSettle();

      expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
      expect(find.text('Tổng số dư hiện tại'), findsNothing);
    });

    testWidgets('ignores stale PIN unlock after app resumes', (tester) async {
      final privacy = DelayedVerifyPrivacyLockService(initialPin: '4321');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeStoreProvider.overrideWithValue(FakeFinanceStore()),
            privacyLockServiceProvider.overrideWithValue(privacy),
          ],
          child: const CashFlowManagerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
      await tester.tap(find.text('Mở khóa'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      privacy.completeVerify();
      await tester.pumpAndSettle();

      expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
      expect(find.text('Tổng số dư hiện tại'), findsNothing);
    });

    testWidgets('stale PIN unlock does not relock newer unlock', (
      tester,
    ) async {
      final privacy = QueuedVerifyPrivacyLockService(initialPin: '4321');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeStoreProvider.overrideWithValue(FakeFinanceStore()),
            privacyLockServiceProvider.overrideWithValue(privacy),
          ],
          child: const CashFlowManagerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
      await tester.tap(find.text('Mở khóa'));
      await tester.pump();

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();

      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
      await tester.tap(find.text('Mở khóa'));
      await tester.pump();

      privacy.completeVerifyAt(1);
      await tester.pumpAndSettle();
      expect(find.text('Tổng số dư hiện tại'), findsOneWidget);

      privacy.completeVerifyAt(0);
      await tester.pumpAndSettle();
      expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
      expect(find.text('Mở khóa CashFlow Manager'), findsNothing);
    });

    testWidgets('relocks existing PIN when app leaves foreground', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            financeStoreProvider.overrideWithValue(FakeFinanceStore()),
            privacyLockServiceProvider.overrideWithValue(
              FakePrivacyLockService(initialPin: '4321'),
            ),
          ],
          child: const CashFlowManagerApp(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '4321');
      await tester.tap(find.text('Mở khóa'));
      await tester.pumpAndSettle();
      expect(find.text('Tổng số dư hiện tại'), findsOneWidget);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pumpAndSettle();

      expect(find.text('Mở khóa CashFlow Manager'), findsOneWidget);
    });
  });
}
