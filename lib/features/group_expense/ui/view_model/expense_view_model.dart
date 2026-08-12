import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../model/expense.dart';
import '../../model/expense_constants.dart';
import '../../model/expense_form_validation.dart';
import '../../model/expense_participant.dart';
import '../../model/expense_receipt.dart';
import '../../model/expense_split.dart';
import '../../model/money_utils.dart';
import '../../repository/currency_service.dart';
import '../../repository/expense_repository.dart';
import '../../repository/group_expense_providers.dart';
import '../../repository/receipt_file_service.dart';
import '../state/expense_form_state.dart';
import 'budget_view_model.dart';
import 'balance_view_model.dart';
import 'expense_dashboard_view_model.dart';
import 'analytics_view_model.dart';

part 'expense_view_model.g.dart';

@riverpod
class ExpenseViewModel extends _$ExpenseViewModel {
  late ExpenseRepository _repository;
  late CurrencyService _currencyService;
  late ReceiptFileService _receiptFileService;

  @override
  Future<ExpenseFormState> build({required int tripId, int? expenseId}) async {
    final repositoryFuture = ref.watch(expenseRepositoryProvider.future);
    final travellerRepositoryFuture =
        ref.watch(travellerRepositoryProvider.future);
    final budgetRepositoryFuture = ref.watch(budgetRepositoryProvider.future);
    _currencyService = ref.watch(currencyServiceProvider);
    _receiptFileService = ref.watch(receiptFileServiceProvider);
    _repository = await repositoryFuture;
    final travellerRepository = await travellerRepositoryFuture;
    final budgetRepository = await budgetRepositoryFuture;
    final categories = await _repository.getCategories();
    final travellers = await travellerRepository.getTravellersForTrip(tripId);
    final budget = await budgetRepository.getBudgetForTrip(tripId);
    final expense =
        expenseId == null ? null : await _repository.getExpenseById(expenseId);
    final participants = expenseId == null
        ? const <ExpenseParticipant>[]
        : await _repository.getParticipants(expenseId);
    final receipt =
        expenseId == null ? null : await _repository.getReceipt(expenseId);
    return ExpenseFormState(
      tripId: tripId,
      baseCurrency: budget?.baseCurrency ?? 'MYR',
      categories: categories,
      travellers: travellers,
      expense: expense,
      participants: participants,
      receipt: receipt,
    );
  }

  Future<bool> save({
    required String title,
    required int? categoryId,
    required String amount,
    required String currency,
    required int? payerId,
    required DateTime expenseDate,
    required List<int> participantIds,
    required ExpenseSplitMethod splitMethod,
    required Map<int, double> customShares,
    required Map<int, double> percentages,
    String? notes,
    String? selectedReceiptPath,
    bool removeReceipt = false,
  }) async {
    final current = state.value;
    if (current == null) return false;
    final validationError = ExpenseFormValidation.title(title) ??
        ExpenseFormValidation.amount(amount) ??
        ExpenseFormValidation.currency(
          currency,
          ExpenseConstants.supportedCurrencies,
        ) ??
        ExpenseFormValidation.requiredSelection(categoryId, 'Category') ??
        ExpenseFormValidation.requiredSelection(payerId, 'Payer');
    if (validationError != null) return _fail(current, validationError);
    if (participantIds.isEmpty) {
      return _fail(current, 'Select at least one participant');
    }

    String? persistedReceiptPath;
    try {
      final originalAmount = double.parse(amount.trim());
      final rate = await _currencyService.getExchangeRate(
        fromCurrency: currency,
        toCurrency: current.baseCurrency,
      );
      final baseAmount = MoneyUtils.roundMoney(originalAmount * rate);
      final participants = _participants(
        method: splitMethod,
        baseAmount: baseAmount,
        userIds: participantIds,
        customShares: customShares,
        percentages: percentages,
        expenseId: current.expense?.expenseId ?? 0,
      );
      state = AsyncData(current.copyWith(
        isSaving: true,
        clearError: true,
        clearSuccess: true,
      ));
      if (selectedReceiptPath != null) {
        persistedReceiptPath =
            await _receiptFileService.persistReceipt(selectedReceiptPath);
      }
      final now = DateTime.now();
      final expense = Expense(
        expenseId: current.expense?.expenseId,
        tripId: current.tripId,
        paidByUserId: payerId!,
        categoryId: categoryId!,
        title: title.trim(),
        originalAmount: originalAmount,
        currencyCode: currency,
        exchangeRate: rate,
        baseAmount: baseAmount,
        expenseDate: expenseDate,
        notes: _optionalText(notes),
        createdAt: current.expense?.createdAt ?? now,
        updatedAt: now,
      );
      final receipt = persistedReceiptPath == null
          ? null
          : ExpenseReceipt(
              expenseId: current.expense?.expenseId ?? 0,
              imagePath: persistedReceiptPath,
              uploadedAt: now,
            );
      final int savedId;
      if (expense.expenseId == null) {
        savedId = await _repository.createExpense(
          expense: expense,
          participants: participants,
          receipt: receipt,
        );
      } else {
        savedId = expense.expenseId!;
        await _repository.updateExpense(
          expense: expense,
          participants: participants,
          receipt: receipt,
          removeReceipt: removeReceipt,
        );
      }
      final oldReceipt = current.receipt;
      if ((removeReceipt || persistedReceiptPath != null) &&
          oldReceipt != null &&
          oldReceipt.imagePath != persistedReceiptPath) {
        await _deleteReceiptBestEffort(oldReceipt.imagePath);
      }
      ref.invalidate(budgetViewModelProvider(current.tripId));
      ref.invalidate(balanceViewModelProvider(current.tripId));
      ref.invalidate(expenseDashboardViewModelProvider);
      ref.invalidate(analyticsViewModelProvider(current.tripId));
      state = AsyncData(current.copyWith(
        expense: expense.copyWith(expenseId: savedId),
        participants: participants,
        receipt: receipt,
        clearReceipt: removeReceipt && receipt == null,
        isSaving: false,
        savedExpenseId: savedId,
        successMessage: expense.expenseId == null
            ? 'Expense added successfully'
            : 'Expense updated successfully',
        clearError: true,
      ));
      return true;
    } on ExpenseSplitException catch (error) {
      if (persistedReceiptPath != null) {
        await _deleteReceiptBestEffort(persistedReceiptPath);
      }
      return _fail(current, error.message);
    } catch (_) {
      if (persistedReceiptPath != null) {
        await _deleteReceiptBestEffort(persistedReceiptPath);
      }
      return _fail(current, 'Unable to save the expense. Please try again.');
    }
  }

  Future<bool> deleteExpense() async {
    final current = state.value;
    final expenseId = current?.expense?.expenseId;
    if (current == null || expenseId == null) return false;
    state = AsyncData(current.copyWith(isSaving: true, clearError: true));
    try {
      await _repository.deleteExpense(expenseId);
      if (current.receipt != null) {
        await _deleteReceiptBestEffort(current.receipt!.imagePath);
      }
      ref.invalidate(budgetViewModelProvider(current.tripId));
      ref.invalidate(balanceViewModelProvider(current.tripId));
      ref.invalidate(expenseDashboardViewModelProvider);
      ref.invalidate(analyticsViewModelProvider(current.tripId));
      state = AsyncData(current.copyWith(
        isSaving: false,
        isDeleted: true,
        successMessage: 'Expense deleted. Balances & budget updated.',
      ));
      return true;
    } catch (_) {
      return _fail(current, 'Unable to delete the expense. Please try again.');
    }
  }

  List<ExpenseParticipant> _participants({
    required ExpenseSplitMethod method,
    required double baseAmount,
    required List<int> userIds,
    required Map<int, double> customShares,
    required Map<int, double> percentages,
    required int expenseId,
  }) =>
      switch (method) {
        ExpenseSplitMethod.equal => ExpenseSplitCalculator.equal(
            expenseId: expenseId,
            baseAmount: baseAmount,
            userIds: userIds,
          ),
        ExpenseSplitMethod.custom => ExpenseSplitCalculator.custom(
            expenseId: expenseId,
            baseAmount: baseAmount,
            shares: {for (final id in userIds) id: customShares[id] ?? 0},
          ),
        ExpenseSplitMethod.percentage => ExpenseSplitCalculator.percentage(
            expenseId: expenseId,
            baseAmount: baseAmount,
            percentages: {
              for (final id in userIds) id: percentages[id] ?? 0,
            },
          ),
      };

  bool _fail(ExpenseFormState current, String message) {
    state = AsyncData(current.copyWith(
      isSaving: false,
      errorMessage: message,
      clearSuccess: true,
    ));
    return false;
  }

  String? _optionalText(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<void> _deleteReceiptBestEffort(String path) async {
    try {
      await _receiptFileService.deleteReceipt(path);
    } catch (_) {
      // The database remains authoritative; an orphaned local file can be
      // cleaned up later without turning a successful data write into error UI.
    }
  }
}
