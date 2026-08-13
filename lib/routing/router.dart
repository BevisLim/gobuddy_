import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/constants.dart';
import '../features/authentication/ui/otp_screen.dart';
import '../features/authentication/ui/welcome_screen.dart';
import '../features/matchmaking/ui/matchmaking_shell_screen.dart';
import '../features/group_expense/ui/expense_dashboard_screen.dart';
import '../features/group_expense/ui/create_budget_screen.dart';
import '../features/group_expense/ui/add_expense_screen.dart';
import '../features/group_expense/ui/edit_budget_screen.dart';
import '../features/group_expense/ui/edit_expense_screen.dart';
import '../features/group_expense/ui/expense_details_screen.dart';
import '../features/group_expense/ui/outstanding_balance_screen.dart';
import '../features/group_expense/ui/record_settlement_screen.dart';
import '../features/group_expense/ui/settlement_history_screen.dart';
import '../features/group_expense/ui/budget_analytics_screen.dart';
import "../features/user_account/ui/user_account_shell.dart";
import '../features/onboarding/ui/onboarding_screen.dart';
import '../features/user_account/ui/app_launching_screen.dart';
import '../features/user_account/ui/login_screen.dart';
import '../features/user_account/ui/register_account_screen.dart';
import '../features/premium/ui/premium_screen.dart';
import '../features/profile/model/profile.dart';
import '../features/profile/ui/account_info_screen.dart';
import '../features/profile/ui/appearances_screen.dart';
import '../features/profile/ui/languages_screen.dart';
import 'routes.dart';

enum SlideDirection {
  right,
  left,
  up,
  down,
}

extension GoRouterStateExtension on GoRouterState {
  SlideRouteTransition slidePage(
    Widget child, {
    SlideDirection direction = SlideDirection.left,
  }) {
    return SlideRouteTransition(
      key: pageKey,
      child: child,
      direction: direction,
    );
  }
}

class SlideRouteTransition extends CustomTransitionPage<void> {
  SlideRouteTransition({
    required super.key,
    required super.child,
    SlideDirection direction = SlideDirection.left,
  }) : super(
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOut,
            );

            Offset begin;
            switch (direction) {
              case SlideDirection.right:
                begin = const Offset(-1.0, 0.0);
                break;
              case SlideDirection.left:
                begin = const Offset(1.0, 0.0);
                break;
              case SlideDirection.up:
                begin = const Offset(0.0, 1.0);
                break;
              case SlideDirection.down:
                begin = const Offset(0.0, -1.0);
                break;
            }
            final tween = Tween(begin: begin, end: Offset.zero);
            final offsetAnimation = tween.animate(curve);

            return SlideTransition(
              position: offsetAnimation,
              child: child,
            );
          },
        );
}

final GoRouter router = GoRouter(
  initialLocation: Routes.splash,
  routes: [
    GoRoute(
      path: Routes.splash,
      pageBuilder: (context, state) => state.slidePage(
        const AppLaunchingScreen(),
        direction: SlideDirection.up,
      ),
    ),
    GoRoute(
      path: Routes.welcome,
      pageBuilder: (context, state) => state.slidePage(const WelcomeScreen()),
    ),
    GoRoute(
      path: Routes.register,
      pageBuilder: (context, state) =>
          state.slidePage(const RegisterAccountScreen()),
    ),
    GoRoute(
      path: Routes.login,
      pageBuilder: (context, state) => state.slidePage(const LoginScreen()),
    ),
    GoRoute(
        path: Routes.otp,
        pageBuilder: (context, state) {
          final map = state.extra as Map?;
          return state.slidePage(
            OtpScreen(
              email: map?['email'],
              isRegister: map?['isRegister'],
            ),
          );
        }),
    GoRoute(
      path: Routes.onboarding,
      pageBuilder: (context, state) =>
          state.slidePage(const OnboardingScreen()),
    ),
    GoRoute(
      path: Routes.main,
      pageBuilder: (context, state) =>
          state.slidePage(const MatchmakingShellScreen()),
    ),
    GoRoute(
      path: Routes.expenseDashboard,
      pageBuilder: (context, state) =>
          state.slidePage(const ExpenseDashboardScreen()),
    ),
    GoRoute(
      path: '${Routes.createBudget}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        CreateBudgetScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.editBudget}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        EditBudgetScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.addExpense}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        AddExpenseScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.expenseDetails}/:tripId/:expenseId',
      pageBuilder: (context, state) => state.slidePage(
        ExpenseDetailsScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
          expenseId: int.parse(state.pathParameters['expenseId']!),
          initialSuccessMessage: state.uri.queryParameters['message'],
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.editExpense}/:tripId/:expenseId',
      pageBuilder: (context, state) => state.slidePage(
        EditExpenseScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
          expenseId: int.parse(state.pathParameters['expenseId']!),
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.outstandingBalance}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        OutstandingBalanceScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.recordSettlement}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        RecordSettlementScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
          initialPayerId: int.tryParse(
            state.uri.queryParameters['payerId'] ?? '',
          ),
          initialPayeeId: int.tryParse(
            state.uri.queryParameters['payeeId'] ?? '',
          ),
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.settlementHistory}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        SettlementHistoryScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
        ),
      ),
    ),
    GoRoute(
      path: '${Routes.budgetAnalytics}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        BudgetAnalyticsScreen(
          tripId: int.parse(state.pathParameters['tripId']!),
        ),
      ),
    ),
    GoRoute(
      path: Routes.userAccount,
      pageBuilder: (context, state) =>
          state.slidePage(const UserAccountScreen()),
    ),
    GoRoute(
      path: Routes.accountInformation,
      pageBuilder: (context, state) {
        final profile = state.extra as Profile;
        return state.slidePage(AccountInfoScreen(originalProfile: profile));
      },
    ),
    GoRoute(
      path: Routes.appearances,
      pageBuilder: (context, state) =>
          state.slidePage(const AppearancesScreen()),
    ),
    GoRoute(
      path: Routes.languages,
      pageBuilder: (context, state) => state.slidePage(const LanguagesScreen()),
    ),
    GoRoute(
      path: Routes.premium,
      pageBuilder: (context, state) {
        final map = state.extra as Map?;
        return state.slidePage(
          PremiumScreen(
            isGoToMain: map?[Constants.isGoToMain] as bool?,
          ),
          direction: SlideDirection.up,
        );
      },
    ),
  ],
);
