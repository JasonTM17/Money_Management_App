import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    bool isRecurring = false,
  }) async {
    try {
      final amount = parseVndAmount(amountInput);
      await _store.addTransaction(
        type: type,
        walletId: walletId,
        categoryId: categoryId,
        amount: amount,
        date: DateTime.now(),
        note: note.trim(),
        isRecurring: isRecurring,
      );
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object catch (error) {
      return error.toString();
    }
  }

  Future<String?> updateTransactionFromForm({
    required FinanceTransaction transaction,
    required String amountInput,
    required String note,
    required String walletId,
    required String categoryId,
    required TransactionType type,
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
        date: transaction.date,
        note: note.trim(),
        isRecurring: isRecurring,
      );
      state = AsyncData(await _store.load());
      return null;
    } on FormatException catch (error) {
      return error.message;
    } on Object catch (error) {
      return error.toString();
    }
  }

  Future<void> deleteTransaction(String id) async {
    await _store.deleteTransaction(id);
    state = AsyncData(await _store.load());
  }
}
