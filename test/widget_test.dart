import 'dart:async';

import 'package:cashflow_manager/features/auth/privacy_gate.dart';
import 'package:cashflow_manager/features/home/finance_controller.dart';
import 'package:cashflow_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_app_fakes.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets('sets up first-run PIN before showing dashboard', (tester) async {
    await _pumpApp(tester, privacy: FakePrivacyLockService());

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
    await _pumpApp(tester, privacy: FakePrivacyLockService());

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
    final privacy = _DelayedSavePrivacyLockService();
    await _pumpApp(tester, privacy: privacy);

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
    final privacy = _DelayedSavePrivacyLockService();
    await _pumpApp(tester, privacy: privacy);

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

  testWidgets('unlocks existing PIN before showing dashboard', (tester) async {
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

  testWidgets('stays locked when app leaves foreground during PIN unlock', (
    tester,
  ) async {
    final privacy = _DelayedVerifyPrivacyLockService(initialPin: '4321');
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
    final privacy = _DelayedVerifyPrivacyLockService(initialPin: '4321');
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

  testWidgets('stale PIN unlock does not relock newer unlock', (tester) async {
    final privacy = _QueuedVerifyPrivacyLockService(initialPin: '4321');
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

  testWidgets('shows CashFlow Manager dashboard shell', (tester) async {
    await _pumpApp(tester);

    expect(find.text('CashFlow Manager'), findsOneWidget);
    expect(find.text('Thêm giao dịch'), findsOneWidget);
    expect(find.text('Tổng số dư hiện tại'), findsOneWidget);
    expect(find.textContaining('Dòng tiền ròng'), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp(r'Biểu đồ thu chi tháng này')),
      findsOneWidget,
    );
  });

  testWidgets('shows budget tab with progress copy', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Ngân sách'));
    await tester.pumpAndSettle();

    expect(find.text('Ngân sách tháng này'), findsOneWidget);
    expect(find.text('Ăn uống'), findsOneWidget);
    expect(find.textContaining('50.000'), findsWidgets);
  });

  testWidgets('creates and deletes a monthly budget', (tester) async {
    final store = FakeFinanceStore();
    await _pumpApp(tester, store: store);

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

    expect(find.textContaining('250.000'), findsOneWidget);

    await tester.tap(find.byTooltip('Xóa ngân sách').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();

    expect(find.textContaining('250.000'), findsNothing);
  });

  testWidgets('creates and deletes a saving goal', (tester) async {
    await _pumpApp(tester);

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
    await _pumpApp(tester);

    await tester.tap(find.text('Ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển tiền giữa ví'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '100000');
    await tester.tap(find.text('Thực hiện chuyển ví'));
    await tester.pumpAndSettle();

    expect(find.textContaining('850.000'), findsOneWidget);
    expect(find.textContaining('20.100.000'), findsOneWidget);
  });

  testWidgets('shows Vietnamese validation for same-wallet transfer', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chuyển tiền giữa ví'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tiền mặt').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Số tiền'), '100000');
    await tester.tap(find.text('Thực hiện chuyển ví'));
    await tester.pumpAndSettle();

    expect(find.text('Ví nguồn và ví nhận phải khác nhau'), findsOneWidget);
  });

  testWidgets('changes theme mode from settings', (tester) async {
    await _usePhoneSurface(tester);
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('settings-action-button')));
    await tester.pumpAndSettle();
    final themeControl = find.byKey(
      const ValueKey('theme-mode-segmented-button'),
    );
    await tester.ensureVisible(themeControl);
    await tester.tap(find.byIcon(Icons.dark_mode));
    await tester.pumpAndSettle();

    expect(find.text('Tối'), findsOneWidget);
  });

  testWidgets('switches app language from settings', (tester) async {
    await _pumpApp(tester);

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

  testWidgets('filters transactions by search query', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('transaction-search-field')),
      'Ăn uống',
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsOneWidget);
    expect(find.text('Lương'), findsNothing);
  });

  testWidgets('filters transactions by wallet category and month', (
    tester,
  ) async {
    await _pumpApp(tester, store: FakeFinanceStore.withMultiMonthReports());

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsOneWidget);
    expect(find.textContaining('18.000.000'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Tiền nhà tháng 4'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String?>, 'Tất cả ví'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ngân hàng').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsNothing);
    expect(find.textContaining('18.000.000'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<String?>, 'Tất cả danh mục'),
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
    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Tiền nhà tháng 4'), findsOneWidget);

    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<DateTime?>, 'Tất cả tháng'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tháng 4/2026').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(ListTile, 'Tiền nhà tháng 4'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsNothing);
  });

  testWidgets('edits transaction date from the transaction sheet', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Ăn sáng'));
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

    expect(find.widgetWithText(ListTile, 'Ăn sáng'), findsOneWidget);
    expect(find.text('15/5/2026'), findsOneWidget);
  });

  testWidgets('deletes a transaction after confirmation', (tester) async {
    await _pumpApp(tester);

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
    await _pumpApp(tester, store: FakeFinanceStore.withTransfer());

    await tester.tap(find.text('Giao dịch'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Chuyển tiền').first);
    await tester.pumpAndSettle();

    expect(find.text('Lưu giao dịch'), findsNothing);
  });

  testWidgets('shows populated report insights and forecast cards', (
    tester,
  ) async {
    await _pumpApp(tester, store: FakeFinanceStore.withReportInsights());

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();

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
  });

  testWidgets('opens report export preview with CSV content', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Xuất CSV/PDF'), 300);
    await tester.tap(find.text('Xuất CSV/PDF'));
    await tester.pumpAndSettle();

    expect(find.text('Nội dung xuất báo cáo'), findsOneWidget);
    expect(
      find.textContaining('CashFlow Manager - Báo cáo tháng'),
      findsWidgets,
    );
    expect(find.textContaining('date,type,wallet_id'), findsOneWidget);
  });

  testWidgets('reports export follows selected month', (tester) async {
    await _pumpApp(tester, store: FakeFinanceStore.withMultiMonthReports());

    await tester.tap(find.text('Báo cáo'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 5/2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Tháng trước'));
    await tester.pumpAndSettle();
    expect(find.text('Tháng 4/2026'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Xuất CSV/PDF'), 300);
    await tester.tap(find.text('Xuất CSV/PDF'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Kỳ báo cáo: 4/2026'), findsWidgets);
    expect(find.textContaining('Tiền nhà tháng 4'), findsOneWidget);
    expect(find.textContaining('Ăn sáng'), findsNothing);
  });

  testWidgets('opens backup restore sheet from settings', (tester) async {
    await _usePhoneSurface(tester);
    await _pumpApp(tester);

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
    await _usePhoneSurface(tester);
    final privacy = FakePrivacyLockService(initialPin: '1234');
    await _pumpApp(tester, privacy: privacy);
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
}

class _DelayedVerifyPrivacyLockService extends FakePrivacyLockService {
  _DelayedVerifyPrivacyLockService({required super.initialPin});

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

class _QueuedVerifyPrivacyLockService extends FakePrivacyLockService {
  _QueuedVerifyPrivacyLockService({required super.initialPin});

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

class _DelayedSavePrivacyLockService extends FakePrivacyLockService {
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

Future<void> _usePhoneSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpApp(
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
