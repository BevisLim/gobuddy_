import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/database/app_database.dart';
import 'core/routing/app_router.dart';
import 'core/services/currency_service.dart';
import 'core/services/local_currency_service.dart';
import 'core/session/app_session.dart';
import 'core/theme/app_theme.dart';
import 'features/group_expense/repositories/contracts/budget_repository.dart';
import 'features/group_expense/repositories/contracts/expense_repository.dart';
import 'features/group_expense/repositories/contracts/settlement_repository.dart';
import 'features/group_expense/repositories/implementations/sqlite_budget_repository.dart';
import 'features/group_expense/repositories/implementations/sqlite_expense_repository.dart';
import 'features/group_expense/repositories/implementations/sqlite_settlement_repository.dart';
import 'shared/repositories/local_traveller_repository.dart';
import 'shared/repositories/local_trip_repository.dart';
import 'shared/repositories/traveller_repository.dart';
import 'shared/repositories/trip_repository.dart';

class GoBuddyApp extends StatelessWidget {
  const GoBuddyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AppDatabase>(create: (_) => AppDatabase.instance),
        Provider<AppSession>(create: (_) => const AppSession()),
        Provider<CurrencyService>(create: (_) => LocalCurrencyService()),
        ProxyProvider<AppDatabase, TravellerRepository>(
          update: (_, database, __) => LocalTravellerRepository(database),
        ),
        ProxyProvider<AppDatabase, TripRepository>(
          update: (_, database, __) => LocalTripRepository(database),
        ),
        ProxyProvider<AppDatabase, BudgetRepository>(
          update: (_, database, __) => SqliteBudgetRepository(database),
        ),
        ProxyProvider<AppDatabase, ExpenseRepository>(
          update: (_, database, __) => SqliteExpenseRepository(database),
        ),
        ProxyProvider<AppDatabase, SettlementRepository>(
          update: (_, database, __) => SqliteSettlementRepository(database),
        ),
      ],
      child: MaterialApp(
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRoutes.dashboard,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
