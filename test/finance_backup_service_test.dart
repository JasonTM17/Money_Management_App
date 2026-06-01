import 'dart:convert';

import 'package:cashflow_manager/core/finance_backup_service.dart';
import 'package:cashflow_manager/core/finance_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const service = FinanceBackupService();

  test('encodes and decodes full finance backup data', () {
    final backup = service.encode(
      wallets: const [
        WalletAccount(
          id: 'cash',
          name: 'Tiền mặt',
          type: WalletType.cash,
          initialBalance: 1000000,
        ),
        WalletAccount(
          id: 'bank',
          name: 'Ngân hàng',
          type: WalletType.bank,
          initialBalance: 2000000,
        ),
      ],
      categories: const [
        FinanceCategory(
          id: 'transfer',
          name: 'Chuyển ví',
          type: TransactionType.transfer,
          colorHex: 0xFF16A34A,
        ),
      ],
      transactions: [
        FinanceTransaction(
          id: 'trf',
          walletId: 'bank',
          toWalletId: 'cash',
          categoryId: 'transfer',
          type: TransactionType.transfer,
          amount: 100000,
          date: DateTime(2026, 5),
          note: 'Backup test',
        ),
      ],
      budgets: const [],
      goals: [
        SavingGoal(
          id: 'goal',
          name: 'Quỹ khẩn cấp',
          targetAmount: 5000000,
          savedAmount: 1000000,
          deadline: DateTime(2026, 12),
        ),
      ],
    );

    final decoded = service.decode(backup);

    expect(decoded.wallets.map((item) => item.id), ['cash', 'bank']);
    expect(decoded.transactions.single.toWalletId, 'cash');
    expect(decoded.goals.single.name, 'Quỹ khẩn cấp');
  });

  test('encrypts and decrypts schema v2 backup data', () async {
    final backup = await service.encodeEncrypted(
      wallets: const [
        WalletAccount(
          id: 'cash',
          name: 'Cash',
          type: WalletType.cash,
          initialBalance: 1000000,
        ),
      ],
      categories: const [
        FinanceCategory(
          id: 'food',
          name: 'Food',
          type: TransactionType.expense,
          colorHex: 0xFFFF9800,
        ),
      ],
      transactions: [
        FinanceTransaction(
          id: 'txn',
          walletId: 'cash',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 100000,
          date: DateTime(2026, 5),
          note: 'Encrypted backup test',
        ),
      ],
      budgets: const [],
      goals: const [],
      passphrase: 'strong-passphrase',
    );

    expect(service.isEncrypted(backup), isTrue);
    expect(() => service.decode(backup), throwsFormatException);

    final plaintext = await service.decryptToPlaintext(
      backup,
      passphrase: 'strong-passphrase',
    );
    final decoded = service.decode(plaintext);

    expect(decoded.wallets.single.id, 'cash');
    expect(decoded.transactions.single.note, 'Encrypted backup test');
  });

  test('rejects encrypted backup with the wrong passphrase', () async {
    final backup = await service.encodeEncrypted(
      wallets: const [
        WalletAccount(
          id: 'cash',
          name: 'Cash',
          type: WalletType.cash,
          initialBalance: 1000000,
        ),
      ],
      categories: const [
        FinanceCategory(
          id: 'food',
          name: 'Food',
          type: TransactionType.expense,
          colorHex: 0xFFFF9800,
        ),
      ],
      transactions: const [],
      budgets: const [],
      goals: const [],
      passphrase: 'strong-passphrase',
    );

    await expectLater(
      service.decryptToPlaintext(backup, passphrase: 'wrong-passphrase'),
      throwsFormatException,
    );
  });
  test('rejects backup without required base lists', () {
    expect(
      () => service.decode('''
{
  "app": "cashflow_manager",
  "schemaVersion": 1,
  "wallets": [],
  "categories": [],
  "transactions": [],
  "budgets": [],
  "goals": []
}
'''),
      throwsFormatException,
    );
  });

  test('rejects encrypted backup after ciphertext tampering', () async {
    final backup = await service.encodeEncrypted(
      wallets: const [
        WalletAccount(
          id: 'cash',
          name: 'Cash',
          type: WalletType.cash,
          initialBalance: 1000000,
        ),
      ],
      categories: const [
        FinanceCategory(
          id: 'food',
          name: 'Food',
          type: TransactionType.expense,
          colorHex: 0xFFFF9800,
        ),
      ],
      transactions: const [],
      budgets: const [],
      goals: const [],
      passphrase: 'strong-passphrase',
    );
    final root = jsonDecode(backup) as Map<String, Object?>;
    root['ciphertext'] = '${root['ciphertext']}AA';

    await expectLater(
      service.decryptToPlaintext(
        jsonEncode(root),
        passphrase: 'strong-passphrase',
      ),
      throwsFormatException,
    );
  });

  test('rejects backup with missing wallet reference', () {
    final backup = service.encode(
      wallets: const [
        WalletAccount(
          id: 'cash',
          name: 'Tiền mặt',
          type: WalletType.cash,
          initialBalance: 1000000,
        ),
      ],
      categories: const [
        FinanceCategory(
          id: 'food',
          name: 'Ăn uống',
          type: TransactionType.expense,
          colorHex: 0xFFFF9800,
        ),
      ],
      transactions: [
        FinanceTransaction(
          id: 'txn',
          walletId: 'missing',
          categoryId: 'food',
          type: TransactionType.expense,
          amount: 100000,
          date: DateTime(2026, 5),
          note: 'Invalid',
        ),
      ],
      budgets: const [],
      goals: const [],
    );

    expect(() => service.decode(backup), throwsFormatException);
  });
}
