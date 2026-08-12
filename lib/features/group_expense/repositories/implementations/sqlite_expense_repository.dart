import '../../../../core/database/app_database.dart';
import '../../../../core/utils/money_utils.dart';
import '../../models/expense.dart';
import '../../models/expense_participant.dart';
import '../../models/expense_receipt.dart';
import '../contracts/expense_repository.dart';

class SqliteExpenseRepository implements ExpenseRepository {
  const SqliteExpenseRepository(this._database);
  final AppDatabase _database;

  void _validate(Expense expense, List<ExpenseParticipant> participants) {
    if (participants.isEmpty ||
        !MoneyUtils.moneyEquals(
            participants.fold<double>(0, (sum, item) => sum + item.shareAmount),
            expense.baseAmount)) {
      throw ArgumentError('Expense shares must equal the base amount');
    }
  }

  @override
  Future<int> createExpense(
      {required Expense expense,
      required List<ExpenseParticipant> participants,
      ExpenseReceipt? receipt}) async {
    _validate(expense, participants);
    final db = await _database.database;
    return db.transaction((txn) async {
      final id = await txn.insert('expenses', expense.toMap());
      for (final participant in participants) {
        await txn.insert(
            'expense_participants', participant.toMap(expenseIdOverride: id));
      }
      if (receipt != null) {
        await txn.insert(
            'expense_receipts', receipt.toMap(expenseIdOverride: id));
      }
      return id;
    });
  }

  @override
  Future<void> updateExpense(
      {required Expense expense,
      required List<ExpenseParticipant> participants,
      ExpenseReceipt? receipt}) async {
    final id = expense.expenseId;
    if (id == null) throw ArgumentError('Expense id is required');
    _validate(expense, participants);
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update('expenses', expense.toMap(),
          where: 'expense_id = ?', whereArgs: [id]);
      await txn.delete('expense_participants',
          where: 'expense_id = ?', whereArgs: [id]);
      for (final participant in participants) {
        await txn.insert(
            'expense_participants', participant.toMap(expenseIdOverride: id));
      }
      await txn
          .delete('expense_receipts', where: 'expense_id = ?', whereArgs: [id]);
      if (receipt != null) {
        await txn.insert(
            'expense_receipts', receipt.toMap(expenseIdOverride: id));
      }
    });
  }

  @override
  Future<void> deleteExpense(int expenseId) async => (await _database.database)
      .delete('expenses', where: 'expense_id = ?', whereArgs: [expenseId]);
  @override
  Future<Expense?> getExpenseById(int expenseId) async {
    final rows = await (await _database.database).query('expenses',
        where: 'expense_id = ?', whereArgs: [expenseId], limit: 1);
    return rows.isEmpty ? null : Expense.fromMap(rows.first);
  }

  @override
  Future<List<Expense>> getExpensesForTrip(int tripId) async {
    final rows = await (await _database.database).query('expenses',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'expense_date DESC');
    return rows.map(Expense.fromMap).toList(growable: false);
  }

  @override
  Future<List<ExpenseParticipant>> getParticipants(int expenseId) async {
    final rows = await (await _database.database).query('expense_participants',
        where: 'expense_id = ?', whereArgs: [expenseId]);
    return rows.map(ExpenseParticipant.fromMap).toList(growable: false);
  }

  @override
  Future<Map<int, double>> calculateNetExpenseBalances(int tripId) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT t.user_id,
        COALESCE((SELECT SUM(e.base_amount) FROM expenses e
          WHERE e.trip_id = ? AND e.paid_by_user_id = t.user_id), 0) -
        COALESCE((SELECT SUM(ep.share_amount) FROM expense_participants ep
          JOIN expenses e ON e.expense_id = ep.expense_id
          WHERE e.trip_id = ? AND ep.user_id = t.user_id), 0) AS balance
      FROM travellers t ORDER BY t.user_id
    ''', [tripId, tripId]);
    return {
      for (final row in rows)
        row['user_id']! as int: (row['balance']! as num).toDouble()
    };
  }
}
