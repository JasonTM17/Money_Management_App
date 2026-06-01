import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/finance_widget_test_helpers.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('shows CashFlow Manager dashboard shell', (tester) async {
    await pumpCashFlowApp(tester);

    expect(find.text('CashFlow Manager'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('add-transaction-action-button')),
      findsOneWidget,
    );
    expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
    expect(find.textContaining('Dòng tiền ròng'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Biểu đồ thu chi tháng này')),
      findsOneWidget,
    );
  });
}
