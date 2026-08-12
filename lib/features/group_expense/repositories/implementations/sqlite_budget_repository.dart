import '../../../../core/database/app_database.dart';
import '../../models/trip_budget.dart';
import '../contracts/budget_repository.dart';

class SqliteBudgetRepository implements BudgetRepository {
  const SqliteBudgetRepository(this._database);
  final AppDatabase _database;
  @override
  Future<int> createBudget(TripBudget budget) async =>
      (await _database.database).insert('trip_budgets', budget.toMap());
  @override
  Future<TripBudget?> getBudgetForTrip(int tripId) async {
    final rows = await (await _database.database).query('trip_budgets',
        where: 'trip_id = ?', whereArgs: [tripId], limit: 1);
    return rows.isEmpty ? null : TripBudget.fromMap(rows.first);
  }

  @override
  Future<double> getTotalSpent(int tripId) async {
    final rows = await (await _database.database).rawQuery(
        'SELECT COALESCE(SUM(base_amount), 0) AS total FROM expenses WHERE trip_id = ?',
        [tripId]);
    return (rows.first['total']! as num).toDouble();
  }

  @override
  Future<void> updateBudget(TripBudget budget) async {
    if (budget.budgetId == null) throw ArgumentError('Budget id is required');
    await (await _database.database).update('trip_budgets', budget.toMap(),
        where: 'budget_id = ?', whereArgs: [budget.budgetId]);
  }
}
