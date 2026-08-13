import 'package:sqflite/sqflite.dart';

import '../model/trip_budget.dart';
import 'budget_repository.dart';

class SqliteBudgetRepository implements BudgetRepository {
  const SqliteBudgetRepository(this.database);
  final Database database;

  @override
  Future<int> createBudget(TripBudget budget) async {
    if (budget.budgetName.trim().isEmpty ||
        budget.budgetAmount <= 0 ||
        budget.baseCurrency.trim().isEmpty) {
      throw ArgumentError('Invalid budget data');
    }
    return database.insert('trip_budgets', budget.toMap());
  }

  @override
  Future<TripBudget?> getBudgetForTrip(int tripId) async {
    final rows = await database.query(
      'trip_budgets',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    return rows.isEmpty ? null : TripBudget.fromMap(rows.first);
  }

  @override
  Future<double> getTotalSpent(int tripId) async {
    final rows = await database.rawQuery(
      'SELECT COALESCE(SUM(base_amount), 0) AS total FROM expenses WHERE trip_id = ?',
      [tripId],
    );
    return (rows.first['total']! as num).toDouble();
  }

  @override
  Future<void> updateBudget(TripBudget budget) async {
    if (budget.budgetId == null) throw ArgumentError('budgetId is required');
    if (budget.budgetName.trim().isEmpty ||
        budget.budgetAmount <= 0 ||
        budget.baseCurrency.trim().isEmpty) {
      throw ArgumentError('Invalid budget data');
    }
    final updated = await database.update(
      'trip_budgets',
      budget.toMap()..remove('budget_id'),
      where: 'budget_id = ?',
      whereArgs: [budget.budgetId],
    );
    if (updated == 0) throw StateError('Budget not found');
  }
}
