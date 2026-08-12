import '../model/category_spending.dart';
import '../model/spending_trend_point.dart';

abstract interface class AnalyticsRepository {
  Future<List<CategorySpending>> getCategorySpending(int tripId);
  Future<List<SpendingTrendPoint>> getSpendingTrend(int tripId);
}
