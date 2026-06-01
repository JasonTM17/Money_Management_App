import 'dart:io';
import 'dart:ui' as ui;

import 'package:cashflow_manager/core/finance_calculator.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:cashflow_manager/data/local_finance_store.dart';
import 'package:cashflow_manager/features/auth/privacy_gate.dart';
import 'package:cashflow_manager/features/home/finance_controller.dart';
import 'package:cashflow_manager/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/test_app_fakes.dart';

const _mediaDir = 'docs/media';
final _captureKey = GlobalKey();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadScreenshotFonts);

  testWidgets('captures hero dashboard media', (tester) async {
    await _captureScreen(tester, 'hero-dashboard.png');
  });

  testWidgets('captures dashboard screenshot', (tester) async {
    await _captureScreen(
      tester,
      'screenshot-dashboard.png',
      ready: find.text('Tổng số dư hiện tại'),
    );
  });

  testWidgets('captures transactions screenshot', (tester) async {
    await _captureScreen(
      tester,
      'screenshot-transactions.png',
      navigate: () async {
        await tester.tap(find.text('Giao dịch'));
        await _pumpFrames(tester);
      },
      ready: find.byKey(const ValueKey('transaction-search-field')),
    );
  });

  testWidgets('captures wallets screenshot', (tester) async {
    await _captureScreen(
      tester,
      'screenshot-wallets.png',
      navigate: () async {
        await tester.tap(find.text('Ví'));
        await _pumpFrames(tester);
      },
      ready: find.text('Chuyển tiền giữa ví'),
    );
  });

  testWidgets('captures budgets screenshot', (tester) async {
    await _captureScreen(
      tester,
      'screenshot-wallets-budgets.png',
      navigate: () async {
        await tester.tap(find.text('Ngân sách'));
        await _pumpFrames(tester);
      },
      ready: find.text('Ngân sách tháng này'),
    );
  });

  testWidgets('captures reports screenshot', (tester) async {
    await _captureScreen(
      tester,
      'screenshot-reports.png',
      navigate: () async {
        await tester.tap(find.text('Báo cáo'));
        await _pumpFrames(tester);
      },
      ready: find.text('Xu hướng thu chi 4 tháng'),
    );
  });

  testWidgets('captures privacy settings screenshot', (tester) async {
    await _captureScreen(
      tester,
      'screenshot-privacy-settings.png',
      navigate: () async {
        await tester.tap(find.byKey(const ValueKey('settings-action-button')));
        await _pumpFrames(tester);
      },
      ready: find.byKey(const ValueKey('privacy-security-panel')),
    );
  });
}

Future<void> _loadScreenshotFonts() async {
  final beVietnamPro = FontLoader('Be Vietnam Pro')
    ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Regular.ttf'))
    ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Medium.ttf'))
    ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-SemiBold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-Bold.ttf'))
    ..addFont(rootBundle.load('assets/fonts/BeVietnamPro-ExtraBold.ttf'));
  await beVietnamPro.load();
  final notoSansJp = FontLoader('Noto Sans JP')
    ..addFont(rootBundle.load('assets/fonts/noto-sans-jp-vf.ttf'));
  await notoSansJp.load();
  final materialIcons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await materialIcons.load();
}

Future<void> _captureScreen(
  WidgetTester tester,
  String fileName, {
  Future<void> Function()? navigate,
  Finder? ready,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  tester.view.devicePixelRatio = 1;
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
    tester.view.resetDevicePixelRatio();
  });

  final outputDir = Directory(_mediaDir)..createSync(recursive: true);
  await _pumpDemoApp(tester, store: _DemoFinanceStore());
  if (navigate != null) await navigate();
  if (ready != null) expect(ready, findsOneWidget);
  await _capture(tester, outputDir, fileName);
}

Future<void> _pumpDemoApp(
  WidgetTester tester, {
  required FakeFinanceStore store,
}) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ProviderScope(
        overrides: [
          financeStoreProvider.overrideWithValue(store),
          privacyLockBypassProvider.overrideWithValue(true),
          privacyLockServiceProvider.overrideWithValue(
            FakePrivacyLockService(initialPin: '1234'),
          ),
        ],
        child: const CashFlowManagerApp(),
      ),
    ),
  );
  await _pumpFrames(tester);
}

Future<void> _pumpFrames(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _capture(
  WidgetTester tester,
  Directory outputDir,
  String fileName,
) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    File(
      '${outputDir.path}/$fileName',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

class _DemoFinanceStore extends FakeFinanceStore {
  _DemoFinanceStore();

  @override
  Future<FinanceState> load() async {
    final now = DateTime(2026, 5, 20);
    final wallets = const [
      WalletAccount(
        id: 'cash',
        name: 'Tiền mặt',
        type: WalletType.cash,
        initialBalance: 2500000,
      ),
      WalletAccount(
        id: 'bank',
        name: 'Ngân hàng',
        type: WalletType.bank,
        initialBalance: 18000000,
      ),
      WalletAccount(
        id: 'ewallet',
        name: 'Ví điện tử',
        type: WalletType.eWallet,
        initialBalance: 3200000,
      ),
      WalletAccount(
        id: 'credit',
        name: 'Thẻ tín dụng',
        type: WalletType.creditCard,
        initialBalance: 0,
      ),
    ];
    final categories = const [
      FinanceCategory(
        id: 'salary',
        name: 'Lương',
        type: TransactionType.income,
        colorHex: 0xFF2196F3,
      ),
      FinanceCategory(
        id: 'food',
        name: 'Ăn uống',
        type: TransactionType.expense,
        colorHex: 0xFFFF9800,
      ),
      FinanceCategory(
        id: 'transport',
        name: 'Di chuyển',
        type: TransactionType.expense,
        colorHex: 0xFF607D8B,
      ),
      FinanceCategory(
        id: 'bill',
        name: 'Hóa đơn',
        type: TransactionType.expense,
        colorHex: 0xFFF44336,
      ),
      FinanceCategory(
        id: 'saving',
        name: 'Tiết kiệm',
        type: TransactionType.expense,
        colorHex: 0xFF16A34A,
      ),
      FinanceCategory(
        id: 'transfer',
        name: 'Chuyển ví',
        type: TransactionType.transfer,
        colorHex: 0xFF16A34A,
      ),
    ];
    final transactions = [
      FinanceTransaction(
        id: 'txn-salary',
        walletId: 'bank',
        categoryId: 'salary',
        type: TransactionType.income,
        amount: 25000000,
        date: DateTime(now.year, now.month, 1),
        note: 'Lương tháng 5',
        isRecurring: true,
      ),
      FinanceTransaction(
        id: 'txn-food',
        walletId: 'cash',
        categoryId: 'food',
        type: TransactionType.expense,
        amount: 420000,
        date: DateTime(now.year, now.month, 20),
        note: 'Ăn tối gia đình',
      ),
      FinanceTransaction(
        id: 'txn-coffee',
        walletId: 'ewallet',
        categoryId: 'food',
        type: TransactionType.expense,
        amount: 85000,
        date: DateTime(now.year, now.month, 19),
        note: 'Cà phê làm việc',
      ),
      FinanceTransaction(
        id: 'txn-rent',
        walletId: 'bank',
        categoryId: 'bill',
        type: TransactionType.expense,
        amount: 6500000,
        date: DateTime(now.year, now.month, 5),
        note: 'Tiền nhà',
        isRecurring: true,
      ),
      FinanceTransaction(
        id: 'txn-transport',
        walletId: 'ewallet',
        categoryId: 'transport',
        type: TransactionType.expense,
        amount: 320000,
        date: DateTime(now.year, now.month, 12),
        note: 'Di chuyển',
      ),
      FinanceTransaction(
        id: 'txn-saving',
        walletId: 'bank',
        categoryId: 'saving',
        type: TransactionType.expense,
        amount: 3000000,
        date: DateTime(now.year, now.month, 8),
        note: 'Gửi quỹ khẩn cấp',
      ),
      FinanceTransaction(
        id: 'txn-april-rent',
        walletId: 'bank',
        categoryId: 'bill',
        type: TransactionType.expense,
        amount: 6500000,
        date: DateTime(2026, 4, 5),
        note: 'Tiền nhà tháng 4',
      ),
    ];
    final budgets = [
      Budget(
        id: 'budget-food',
        categoryId: 'food',
        month: DateTime(now.year, now.month),
        limitAmount: 1500000,
      ),
      Budget(
        id: 'budget-bill',
        categoryId: 'bill',
        month: DateTime(now.year, now.month),
        limitAmount: 7000000,
      ),
    ];
    final goals = [
      SavingGoal(
        id: 'goal-emergency',
        name: 'Quỹ khẩn cấp',
        targetAmount: 50000000,
        savedAmount: 18500000,
        deadline: DateTime(2026, 11, 1),
      ),
      SavingGoal(
        id: 'goal-travel',
        name: 'Du lịch Đà Nẵng',
        targetAmount: 12000000,
        savedAmount: 4600000,
        deadline: DateTime(2026, 8, 15),
      ),
    ];
    final summary = const FinanceCalculator().dashboardSummary(
      wallets: wallets,
      transactions: transactions,
      budgets: budgets,
      month: now,
    );
    return FinanceState(
      wallets: wallets,
      categories: categories,
      transactions: transactions,
      budgets: budgets,
      goals: goals,
      summary: summary,
      reportMonth: now,
    );
  }
}
