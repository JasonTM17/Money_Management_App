import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/finance_widget_test_helpers.dart';
import '../test_app_fakes.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('transactions', () {
    testWidgets('filters transactions by search query', (tester) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Giao dịch'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('transaction-search-field')),
        'Ăn uống',
      );
      await tester.pumpAndSettle();

      expect(find.text('Ăn sáng'), findsOneWidget);
      expect(find.text('Lương'), findsNothing);
    });

    testWidgets('filters transactions by wallet category and month', (
      tester,
    ) async {
      await pumpCashFlowApp(
        tester,
        store: FakeFinanceStore.withMultiMonthReports(),
      );

      await tester.tap(find.text('Giao dịch'));
      await tester.pumpAndSettle();
      expect(find.text('Ăn sáng'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();
      expect(find.textContaining('18.000.000'), findsWidgets);
      expect(find.text('Tiền nhà tháng 4'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, 'Tất cả ví'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ngân hàng').last);
      await tester.pumpAndSettle();
      expect(find.text('Ăn sáng'), findsNothing);
      expect(find.textContaining('18.000.000'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String?>,
          'Tất cả danh mục',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn uống').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('18.000.000'), findsNothing);
      expect(find.text('Không có giao dịch phù hợp'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<String?>, 'Ngân hàng'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tất cả ví').last);
      await tester.pumpAndSettle();
      expect(find.text('Ăn sáng'), findsOneWidget);
      expect(find.text('Tiền nhà tháng 4'), findsOneWidget);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<DateTime?>, 'Tất cả tháng'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tháng 4/2026').last);
      await tester.pumpAndSettle();
      expect(find.text('Tiền nhà tháng 4'), findsOneWidget);
      expect(find.text('Ăn sáng'), findsNothing);
    });

    testWidgets('edits transaction date from the transaction sheet', (
      tester,
    ) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Giao dịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ăn sáng'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('transaction-date-field')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK').last);
      await tester.pumpAndSettle();
      final submitButton = find.byKey(
        const ValueKey('transaction-submit-button'),
      );
      await tester.ensureVisible(submitButton);
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      expect(find.text('Ăn sáng'), findsOneWidget);
      expect(find.text('15/5/2026'), findsOneWidget);
    });

    testWidgets('deletes a transaction after confirmation', (tester) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Giao dịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Xóa giao dịch').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Ăn sáng'), findsNothing);
    });

    testWidgets('does not open income expense editor for transfers', (
      tester,
    ) async {
      await pumpCashFlowApp(tester, store: FakeFinanceStore.withTransfer());

      await tester.tap(find.text('Giao dịch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chuyển tiền').first);
      await tester.pumpAndSettle();

      expect(find.text('Lưu giao dịch'), findsNothing);
    });
  });
}
