import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/finance_widget_test_helpers.dart';
import '../test_app_fakes.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('dashboard and budgets', () {
    testWidgets('main shell stays usable on small phone with large text', (
      tester,
    ) async {
      await usePhoneSurface(
        tester,
        size: const Size(360, 800),
        textScaleFactor: 1.6,
      );
      await pumpCashFlowApp(
        tester,
        store: FakeFinanceStore.withReportInsights(),
      );

      expect(
        find.byKey(const ValueKey('add-transaction-action-button')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('settings-action-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(
        find.byKey(const ValueKey('add-transaction-action-button')),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('transaction-submit-button')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      Navigator.of(
        tester.element(find.byKey(const ValueKey('transaction-submit-button'))),
      ).pop();
      await tester.pumpAndSettle();

      for (final icon in [
        Icons.receipt_long_outlined,
        Icons.account_balance_wallet_outlined,
        Icons.savings_outlined,
        Icons.pie_chart_outline,
      ]) {
        await tester.tap(find.byIcon(icon).last);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.byKey(const ValueKey('settings-action-button')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dashboard renders without overflow at 360x640', (tester) async {
      await usePhoneSurface(tester, size: const Size(360, 640));
      await pumpCashFlowApp(tester);

      expect(find.byKey(const ValueKey('add-transaction-action-button')),
          findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows budget tab with progress copy', (tester) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Ngân sách'));
      await tester.pumpAndSettle();

      expect(find.text('Ngân sách tháng này'), findsOneWidget);
      expect(find.text('Ăn uống'), findsOneWidget);
      expect(find.textContaining('50.000'), findsWidgets);
    });

    testWidgets('creates and deletes a monthly budget', (tester) async {
      final store = FakeFinanceStore();
      await pumpCashFlowApp(tester, store: store);

      await tester.tap(find.text('Ngân sách'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm ngân sách'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Hạn mức tháng'),
        '250000',
      );
      await tester.tap(find.text('Lưu ngân sách'));
      await tester.pumpAndSettle();

      expect(find.textContaining('250.000'), findsWidgets);

      await tester.tap(find.byTooltip('Xóa ngân sách').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(find.textContaining('250.000'), findsNothing);
    });
  });
}
