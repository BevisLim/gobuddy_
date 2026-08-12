import '../../models/expense.dart';
import '../../models/expense_participant.dart';
import '../../models/expense_receipt.dart';

abstract interface class ExpenseRepository {
  Future<List<Expense>> getExpensesForTrip(int tripId);
  Future<Expense?> getExpenseById(int expenseId);
  Future<int> createExpense(
      {required Expense expense,
      required List<ExpenseParticipant> participants,
      ExpenseReceipt? receipt});
  Future<void> updateExpense(
      {required Expense expense,
      required List<ExpenseParticipant> participants,
      ExpenseReceipt? receipt});
  Future<void> deleteExpense(int expenseId);
  Future<List<ExpenseParticipant>> getParticipants(int expenseId);
  Future<Map<int, double>> calculateNetExpenseBalances(int tripId);
}
