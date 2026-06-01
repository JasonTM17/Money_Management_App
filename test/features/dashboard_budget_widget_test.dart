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
