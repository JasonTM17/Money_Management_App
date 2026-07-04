import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/finance_widget_test_helpers.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('wallets and saving goals', () {
    testWidgets('renders without overflow at 360x640', (tester) async {
      await usePhoneSurface(tester, size: const Size(360, 640));
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Ví'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('creates and deletes a saving goal', (tester) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Ví'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thêm mục tiêu'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Tên mục tiêu'),
        'Du lịch',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền mục tiêu'),
        '3000000',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Đã tiết kiệm'),
        '500000',
      );
      await tester.tap(find.text('Lưu mục tiêu'));
      await tester.pumpAndSettle();

      expect(find.text('Du lịch'), findsOneWidget);
      expect(find.textContaining('2.500.000'), findsOneWidget);
      expect(find.textContaining('Gợi ý tiết kiệm'), findsOneWidget);

      final deleteGoalButton = find.byKey(const ValueKey('delete-goal-goal-1'));
      await tester.scrollUntilVisible(deleteGoalButton, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -180));
      await tester.pumpAndSettle();
      await tester.tap(deleteGoalButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Du lịch'), findsNothing);
    });

    testWidgets('transfers money between wallets from wallet tab', (
      tester,
    ) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Ví'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chuyển tiền giữa ví'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền'),
        '100000',
      );
      await tester.tap(find.text('Thực hiện chuyển ví'));
      await tester.pumpAndSettle();

      expect(find.textContaining('850.000'), findsOneWidget);
      expect(find.textContaining('20.100.000'), findsOneWidget);
    });

    testWidgets('shows Vietnamese validation for same-wallet transfer', (
      tester,
    ) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.text('Ví'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chuyển tiền giữa ví'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tiền mặt').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Số tiền'),
        '100000',
      );
      await tester.tap(find.text('Thực hiện chuyển ví'));
      await tester.pumpAndSettle();

      expect(find.text('Ví nguồn và ví nhận phải khác nhau'), findsOneWidget);
    });
  });
}
