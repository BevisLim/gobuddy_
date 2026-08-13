import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../common/local/database_provider.dart';
import '../model/app_session.dart';
import 'budget_repository.dart';
import 'analytics_repository.dart';
import 'currency_service.dart';
import 'expense_repository.dart';
import 'local_currency_service.dart';
import 'local_traveller_repository.dart';
import 'local_trip_repository.dart';
import 'local_receipt_file_service.dart';
import 'receipt_file_service.dart';
import 'settlement_repository.dart';
import 'sqlite_budget_repository.dart';
import 'sqlite_analytics_repository.dart';
import 'sqlite_expense_repository.dart';
import 'sqlite_settlement_repository.dart';
import 'traveller_repository.dart';
import 'trip_repository.dart';

final appSessionProvider = Provider<AppSession>((ref) => const AppSession());

final currencyServiceProvider =
    Provider<CurrencyService>((ref) => LocalCurrencyService());

final receiptFileServiceProvider =
    Provider<ReceiptFileService>((ref) => LocalReceiptFileService());

final travellerRepositoryProvider =
    FutureProvider<TravellerRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return LocalTravellerRepository(database);
});

final tripRepositoryProvider = FutureProvider<TripRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return LocalTripRepository(database);
});

final budgetRepositoryProvider = FutureProvider<BudgetRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return SqliteBudgetRepository(database);
});

final analyticsRepositoryProvider =
    FutureProvider<AnalyticsRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return SqliteAnalyticsRepository(database);
});

final expenseRepositoryProvider =
    FutureProvider<ExpenseRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return SqliteExpenseRepository(database);
});

final settlementRepositoryProvider =
    FutureProvider<SettlementRepository>((ref) async {
  final database = await ref.watch(databaseProvider.future);
  return SqliteSettlementRepository(database);
});
