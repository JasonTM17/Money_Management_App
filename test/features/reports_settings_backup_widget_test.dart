import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/finance_widget_test_helpers.dart';
import '../test_app_fakes.dart';

Future<void> _openReportsTab(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.pie_chart_outline).last);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('reports, settings, and backups', () {
    testWidgets('changes theme mode from settings', (tester) async {
      await usePhoneSurface(tester);
      await pumpCashFlowApp(tester);

      await tester.tap(find.byKey(const ValueKey('settings-action-button')));
      await tester.pumpAndSettle();
      final themeControl = find.byKey(
        const ValueKey('theme-mode-segmented-button'),
      );
      await tester.scrollUntilVisible(themeControl, 300);
      await tester.pumpAndSettle();
      final themeRect = tester.getRect(themeControl);
      await tester.tapAt(
        Offset(themeRect.right - themeRect.width / 6, themeRect.center.dy),
      );
      await tester.pumpAndSettle();

      expect(find.text('Tối'), findsOneWidget);
    });

    testWidgets('switches app language from settings', (tester) async {
      await pumpCashFlowApp(tester);

      await tester.tap(find.byKey(const ValueKey('settings-action-button')));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Tiếng Anh'), 300);
      expect(find.text('Ngôn ngữ'), findsOneWidget);

      await tester.tap(find.text('Tiếng Anh'));
      await tester.pumpAndSettle();
      expect(find.text('Language'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('Japanese'), 300);
      await tester.tap(find.text('Japanese'));
      await tester.pumpAndSettle();
      expect(find.text('言語'), findsOneWidget);
    });

    testWidgets('shows populated report insights and forecast cards', (
      tester,
    ) async {
      await pumpCashFlowApp(
        tester,
        store: FakeFinanceStore.withReportInsights(),
      );

      await _openReportsTab(tester);

      expect(find.text('Xu hướng thu chi 4 tháng'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Chi tiêu theo danh mục'), 300);
      expect(find.text('Chi tiêu theo danh mục'), findsOneWidget);
      expect(find.textContaining('Ăn uống: 350.000'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Danh mục chi tiêu nhiều nhất'),
        300,
      );
      expect(find.text('Ăn uống'), findsWidgets);
      expect(find.textContaining('350.000'), findsWidgets);
      await tester.scrollUntilVisible(find.text('Dự báo dòng tiền'), 300);
      expect(find.text('Nhắc hóa đơn sắp tới'), findsOneWidget);
      expect(find.text('Tiền điện'), findsOneWidget);
      expect(find.textContaining('Đã tính trong dự báo'), findsOneWidget);
    });

    testWidgets('opens report export preview with CSV content', (tester) async {
      await pumpCashFlowApp(tester);

      await _openReportsTab(tester);
      final exportAction = find.byKey(const ValueKey('report-export-action'));
      await tester.scrollUntilVisible(exportAction, 300);
      await tester.tap(exportAction);
      await tester.pumpAndSettle();

      expect(find.text('Nội dung xuất báo cáo'), findsOneWidget);
      expect(
        find.textContaining('CashFlow Manager - Báo cáo tháng'),
        findsWidgets,
      );
      expect(find.textContaining('date,type,wallet_id'), findsOneWidget);
    });

    testWidgets('reports export follows selected month', (tester) async {
      await pumpCashFlowApp(
        tester,
        store: FakeFinanceStore.withMultiMonthReports(),
      );

      await _openReportsTab(tester);
      expect(find.text('Tháng 5/2026'), findsOneWidget);

      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pumpAndSettle();
      expect(find.text('Tháng 4/2026'), findsOneWidget);

      final exportAction = find.byKey(const ValueKey('report-export-action'));
      await tester.scrollUntilVisible(exportAction, 300);
      await tester.tap(exportAction);
      await tester.pumpAndSettle();

      expect(find.textContaining('Kỳ báo cáo: 4/2026'), findsWidgets);
      expect(find.textContaining('Tiền nhà tháng 4'), findsOneWidget);
      expect(find.textContaining('Ăn sáng'), findsNothing);
    });

    testWidgets('opens backup restore sheet from settings', (tester) async {
      await usePhoneSurface(tester);
      await pumpCashFlowApp(tester);

      await tester.tap(find.byKey(const ValueKey('settings-action-button')));
      await tester.pumpAndSettle();
      final backupCard = find.byKey(const ValueKey('backup-restore-card'));
      await tester.scrollUntilVisible(backupCard, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(backupCard);
      await tester.pumpAndSettle();

      expect(find.text('Sao lưu / khôi phục dữ liệu'), findsOneWidget);
      expect(find.text('Xuất backup JSON'), findsOneWidget);
      expect(find.text('Khôi phục từ file JSON'), findsOneWidget);
      expect(find.textContaining('dữ liệu tài chính nhạy cảm'), findsOneWidget);
    });

    testWidgets('reset data requires confirmation and re-auth', (tester) async {
      await usePhoneSurface(tester);
      final privacy = FakePrivacyLockService(initialPin: '1234');
      await pumpCashFlowApp(tester, privacy: privacy);
      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '1234');
      await tester.tap(find.text('Mở khóa'));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('settings-action-button')));
      await tester.pumpAndSettle();
      final resetCard = find.byKey(const ValueKey('reset-data-card'));
      await tester.scrollUntilVisible(resetCard, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(resetCard);
      await tester.pumpAndSettle();

      expect(find.text('Xác nhận đặt lại dữ liệu'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận đặt lại dữ liệu'), findsNothing);

      await tester.scrollUntilVisible(resetCard, 300);
      await tester.drag(find.byType(ListView), const Offset(0, -120));
      await tester.pumpAndSettle();
      await tester.tap(resetCard);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đặt lại dữ liệu').last);
      await tester.pumpAndSettle();

      expect(find.text('Xác thực lại'), findsOneWidget);
      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '0000');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('PIN không đúng'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'PIN'), '1234');
      await tester.tap(find.text('Xác nhận'));
      await tester.pumpAndSettle();

      expect(privacy.verifyCount, 3);
      expect(
        find.text('Đã reset dữ liệu về trạng thái ban đầu.'),
        findsOneWidget,
      );
    });
  });
}
