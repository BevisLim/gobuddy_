import '../model/expense.dart';
import '../model/expense_participant.dart';
import '../model/expense_receipt.dart';
import '../model/expense_category.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getExpensesForTrip(int tripId);
  Future<List<ExpenseCategory>> getCategories();
  Future<Expense?> getExpenseById(int expenseId);
  Future<ExpenseReceipt?> getReceipt(int expenseId);
  Future<int> createExpense({
    required Expense expense,
    required List<ExpenseParticipant> participants,
    ExpenseReceipt? receipt,
  });
  Future<void> updateExpense({
    required Expense expense,
    required List<ExpenseParticipant> participants,
    ExpenseReceipt? receipt,
    bool removeReceipt = false,
  });
  Future<void> deleteExpense(int expenseId);
  Future<List<ExpenseParticipant>> getParticipants(int expenseId);
  Future<Map<int, double>> calculateNetExpenseBalances(int tripId);
}
