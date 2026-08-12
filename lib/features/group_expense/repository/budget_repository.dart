import '../model/trip_budget.dart';

abstract interface class BudgetRepository {
  Future<TripBudget?> getBudgetForTrip(int tripId);
  Future<int> createBudget(TripBudget budget);
  Future<void> updateBudget(TripBudget budget);
  Future<double> getTotalSpent(int tripId);
}
