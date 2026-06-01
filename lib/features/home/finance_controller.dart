import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/finance_backup_service.dart';
import '../../core/finance_models.dart';
import '../../core/money.dart';
import '../../data/local_finance_store.dart';

final financeStoreProvider = Provider<LocalFinanceStore>(
  (ref) => LocalFinanceStore(),
);

final financeControllerProvider =
    AsyncNotifierProvider<FinanceController, FinanceState>(
      FinanceController.new,
    );

class FinanceController extends AsyncNotifier<FinanceState> {
  late final LocalFinanceStore _store = ref.read(financeStoreProvider);

  @override
  Future<FinanceState> build() => _store.load();

  Future<String?> addExpenseFromForm({
    required String amountInput,
    required String note,
    required String walletId,
    required String categoryId,
    required TransactionType type,
    required DateTime date,
    bool isRecurring = false,
  }) async {
    try {
      final amount = parseVndAmount(amountInput);
      await _store.addTransaction(
        type: type,
        walletId: walletId,
        categoryId: categoryId,
        amount: amount,
        date: date,
        note: note.trim(),
        isRecurring: isRecurring,
      );
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'unknownError';
    }
  }

  Future<String?> updateTransactionFromForm({
    required FinanceTransaction transaction,
    required String amountInput,
    required String note,
    required String walletId,
    required String categoryId,
    required TransactionType type,
    required DateTime date,
    bool isRecurring = false,
  }) async {
    try {
      final amount = parseVndAmount(amountInput);
      await _store.updateTransaction(
        id: transaction.id,
        type: type,
        walletId: walletId,
        categoryId: categoryId,
        amount: amount,
        date: date,
        note: note.trim(),
        isRecurring: isRecurring,
      );
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'unknownError';
    }
  }

  Future<String?> transferFromForm({
    required String amountInput,
    required String note,
    required String fromWalletId,
    required String toWalletId,
  }) async {
    try {
      final amount = parseVndAmount(amountInput);
      await _store.transfer(
        fromWalletId: fromWalletId,
        toWalletId: toWalletId,
        amount: amount,
        date: DateTime.now(),
        note: note.trim(),
      );
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'unknownError';
    }
  }

  Future<String> exportBackup() => _store.exportBackup();

  Future<String> exportEncryptedBackup(String passphrase) =>
      _store.exportEncryptedBackup(passphrase);

  bool isEncryptedBackup(String input) =>
      const FinanceBackupService().isEncrypted(input);

  Future<String> decryptBackup(String input, {required String passphrase}) =>
      const FinanceBackupService().decryptToPlaintext(
        input,
        passphrase: passphrase,
      );

  FinanceBackupPreview previewBackup(String input) =>
      const FinanceBackupService().preview(input);

  Future<String?> restoreBackup(String input) async {
    try {
      await _store.restoreBackup(input);
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'unknownError';
    }
  }

  Future<String?> upsertBudgetFromForm({
    Budget? budget,
    required String categoryId,
    required String limitAmountInput,
    DateTime? month,
  }) async {
    try {
      final limitAmount = parseVndAmount(limitAmountInput);
      if (budget == null) {
        await _store.upsertBudget(
          categoryId: categoryId,
          month: month ?? DateTime.now(),
          limitAmount: limitAmount,
        );
      } else {
        await _store.updateBudget(
          id: budget.id,
          categoryId: categoryId,
          month: month ?? budget.month,
          limitAmount: limitAmount,
        );
      }
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'unknownError';
    }
  }

  Future<void> deleteBudget(String id) async {
    await _store.deleteBudget(id);
    state = AsyncData(await _store.load());
  }

  Future<void> deleteGoal(String id) async {
    await _store.deleteGoal(id);
    state = AsyncData(await _store.load());
  }

  Future<String?> saveGoalFromForm({
    SavingGoal? goal,
    required String name,
    required String targetInput,
    required String savedInput,
    required DateTime deadline,
  }) async {
    try {
      final targetAmount = parseVndAmount(targetInput);
      final savedAmount = parseVndAmount(savedInput);
      await _store.saveGoal(
        id: goal?.id,
        name: name,
        targetAmount: targetAmount,
        savedAmount: savedAmount,
        deadline: deadline,
      );
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object {
      return 'unknownError';
    }
  }

  Future<String?> resetData() async {
    try {
      await _store.resetData();
      state = AsyncData(await _store.load());
      return null;
    } on Object {
      return 'unknownError';
    }
  }

  Future<void> deleteTransaction(String id) async {
    await _store.deleteTransaction(id);
    state = AsyncData(await _store.load());
  }
}
