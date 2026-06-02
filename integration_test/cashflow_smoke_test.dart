import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../test/helpers/finance_widget_test_helpers.dart';
import '../test/test_app_fakes.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets(
    'release smoke covers privacy, UI navigation, and core finance',
    (tester) async {
      await usePhoneSurface(tester);
      final privacy = FakePrivacyLockService();
      await pumpCashFlowApp(
        tester,
        store: FakeFinanceStore.withReportInsights(),
        privacy: privacy,
      );

      await _createFirstRunPin(tester);
      expect(find.text('CashFlow Manager'), findsOneWidget);
      _expectNoFrameworkException(tester);

      await _addInvalidThenValidExpense(tester);
      await _openBottomTab(tester, Icons.receipt_long_outlined);
      expect(
        find.byKey(const ValueKey('transaction-search-field')),
        findsOneWidget,
      );

      await _openBottomTab(tester, Icons.account_balance_wallet_outlined);
      await _transferBetweenWallets(tester);
      await _createSavingGoal(tester);

      await _openBottomTab(tester, Icons.savings_outlined);
      expect(find.byIcon(Icons.warning_amber), findsWidgets);

      await _openBottomTab(tester, Icons.pie_chart_outline);
      await _openReportExportPreview(tester);

      await _openSettingsAndPrivacyEntries(tester, privacy);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byIcon(Icons.fingerprint), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      _expectNoFrameworkException(tester);
    },
    timeout: const Timeout(Duration(minutes: 10)),
  );
}

Future<void> _createFirstRunPin(WidgetTester tester) async {
  await _enterTextByAnyLabel(
    tester,
    labels: const ['PIN mới', 'New PIN', '新しいPIN'],
    fallbackIndex: 0,
    text: '1234',
  );
  await tester.pump();
  await _enterTextByAnyLabel(
    tester,
    labels: const ['Nhập lại PIN', 'Confirm PIN', 'PINを再入力'],
    fallbackIndex: 1,
    text: '1234',
  );
  await tester.tap(find.byType(FilledButton).first);
  await tester.pumpAndSettle();
}

Future<void> _enterTextByAnyLabel(
  WidgetTester tester, {
  required List<String> labels,
  required int fallbackIndex,
  required String text,
}) async {
  for (final label in labels) {
    final labeledField = find.widgetWithText(TextField, label);
    if (labeledField.evaluate().isNotEmpty) {
      await tester.ensureVisible(labeledField.first);
      await tester.enterText(labeledField.first, text);
      return;
    }
  }

  final fields = find.byType(TextField);
  final fieldCount = fields.evaluate().length;
  if (fieldCount > fallbackIndex) {
    await tester.ensureVisible(fields.at(fallbackIndex));
    await tester.enterText(fields.at(fallbackIndex), text);
    return;
  }

  throw TestFailure(
    'Could not find one of $labels or TextField index $fallbackIndex; found $fieldCount TextField widgets.',
  );
}

Future<void> _addInvalidThenValidExpense(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('add-transaction-action-button')));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextField).at(0), '0');
  await tester.tap(find.byKey(const ValueKey('transaction-submit-button')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const ValueKey('transaction-submit-button')),
    findsOneWidget,
  );

  await tester.enterText(find.byType(TextField).at(0), '60000');
  await tester.enterText(find.byType(TextField).at(1), 'release smoke expense');
  await tester.tap(find.byKey(const ValueKey('transaction-submit-button')));
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('transaction-submit-button')), findsNothing);
}

Future<void> _transferBetweenWallets(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.swap_horiz).first);
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), '100000');
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
}

Future<void> _createSavingGoal(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.savings).first);
  await tester.pumpAndSettle();
  expect(find.byType(TextField), findsNWidgets(3));
  await tester.enterText(find.byType(TextField).at(0), 'Smoke goal');
  await tester.enterText(find.byType(TextField).at(1), '3000000');
  await tester.enterText(find.byType(TextField).at(2), '500000');
  await tester.tap(find.byType(FilledButton).last);
  await tester.pumpAndSettle();
  expect(find.text('Smoke goal'), findsOneWidget);
}

Future<void> _openReportExportPreview(WidgetTester tester) async {
  final exportAction = find.byKey(const ValueKey('report-export-action'));
  await tester.scrollUntilVisible(exportAction, 300);
  await tester.tap(exportAction);
  await tester.pumpAndSettle();
  expect(find.byType(SelectableText), findsOneWidget);
  expect(find.byIcon(Icons.picture_as_pdf), findsOneWidget);
  await _popFrom(tester, find.byType(SelectableText));
}

Future<void> _openSettingsAndPrivacyEntries(
  WidgetTester tester,
  FakePrivacyLockService privacy,
) async {
  await tester.tap(find.byKey(const ValueKey('settings-action-button')));
  await tester.pumpAndSettle();

  final biometricSwitch = find.byKey(const ValueKey('biometric-unlock-switch'));
  await tester.scrollUntilVisible(biometricSwitch, 300);
  await tester.tap(biometricSwitch);
  await tester.pumpAndSettle();
  expect(privacy.biometricEnabled, isTrue);

  final backupCard = find.byKey(const ValueKey('backup-restore-card'));
  await tester.scrollUntilVisible(backupCard, 300);
  await tester.tap(backupCard);
  await tester.pumpAndSettle();
  expect(find.byIcon(Icons.restore), findsOneWidget);
  await _popFrom(tester, find.byIcon(Icons.restore));

  final resetCard = find.byKey(const ValueKey('reset-data-card'));
  await tester.scrollUntilVisible(resetCard, 300);
  await tester.tap(resetCard);
  await tester.pumpAndSettle();
  expect(find.byType(AlertDialog), findsOneWidget);
  await _popFrom(tester, find.byType(AlertDialog));
  await _popFrom(tester, resetCard);
}

Future<void> _openBottomTab(WidgetTester tester, IconData icon) async {
  final destinationIcon = find.descendant(
    of: find.byType(NavigationBar),
    matching: find.byIcon(icon),
  );
  expect(destinationIcon, findsOneWidget);
  await tester.tap(destinationIcon);
  await tester.pumpAndSettle();
}

void _expectNoFrameworkException(WidgetTester tester) {
  expect(tester.takeException(), isNull);
}

Future<void> _popFrom(WidgetTester tester, Finder finder) async {
  Navigator.of(tester.element(finder.first)).pop();
  await tester.pumpAndSettle();
}
