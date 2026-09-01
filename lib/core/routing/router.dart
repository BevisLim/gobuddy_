import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/ui/group_collaboration_screen.dart';
import '../../features/user_account/ui/login_confirmation.dart';
import '../../features/user_account/ui/welcome_screen.dart';
import '../../features/matchmaking/ui/matchmaking_shell_screen.dart';
import '../../features/matchmaking/ui/view_model/matchmaking_view_model.dart';
import '../../features/matchmaking/model/matchmaking_page.dart';
import '../../features/group_collaboration/ui/messages_screen.dart';
import '../../features/group_expense/ui/expense_dashboard_screen.dart';
import '../../features/group_expense/ui/create_budget_screen.dart';
import '../../features/group_expense/ui/add_expense_screen.dart';
import '../../features/group_expense/ui/edit_budget_screen.dart';
import '../../features/group_expense/ui/edit_expense_screen.dart';
import '../../features/group_expense/ui/expense_details_screen.dart';
import '../../features/group_expense/ui/outstanding_balance_screen.dart';
import '../../features/group_expense/ui/record_settlement_screen.dart';
import '../../features/group_expense/ui/settlement_history_screen.dart';
import '../../features/group_expense/ui/budget_analytics_screen.dart';
import '../../features/user_account/ui/user_account_shell.dart';
import '../../features/user_account/ui/app_launching_screen.dart';
import '../../features/user_account/ui/forgot_password_screen.dart';
import '../../features/user_account/ui/identity_verification_screen.dart';
import '../../features/user_account/ui/settings/blocked_users_screen.dart';
import '../../features/user_account/ui/settings/change_password_screen.dart';
import '../../features/user_account/ui/settings/settings_screen.dart';
import '../../features/user_account/ui/login_screen.dart';
import '../../features/user_account/ui/register_account_screen.dart';
import '../../features/user_account/ui/personal_information_setup_screen.dart';
import '../../features/user_account/ui/set_password_screen.dart';
import '../../features/user_account/ui/profile_onboarding_screen.dart';
import '../../features/user_account/ui/legal/privacy_policy_screen.dart';
import '../../features/user_account/ui/legal/terms_screen.dart';
import '../../features/safety/ui/add_emergency_contact_screen.dart';
import '../../features/safety/ui/emergency_contacts_screen.dart';
import '../../features/safety/ui/live_location_screen.dart';
import '../../features/safety/ui/sos_screen.dart';
import '../../features/safety/ui/safety_check_in_settings_screen.dart';

import 'routes.dart';

enum SlideDirection { right, left, up, down }

extension GoRouterStateExtension on GoRouterState {
  NoTransitionPage<void> navigationPage(Widget child) {
    return NoTransitionPage<void>(key: pageKey, child: child);
  }

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

           return SlideTransition(position: offsetAnimation, child: child);
         },
       );
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter router = GoRouter(
  navigatorKey: rootNavigatorKey,
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
      path: Routes.forgotPassword,
      pageBuilder: (context, state) =>
          state.slidePage(const ForgotPasswordScreen()),
    ),
    GoRoute(
      path: Routes.otp,
      pageBuilder: (context, state) {
        final map = state.extra as Map?;
        return state.slidePage(
          OtpScreen(email: map?['email'] as String? ?? ''),
        );
      },
    ),
    GoRoute(
      path: Routes.setPassword,
      pageBuilder: (context, state) =>
          state.slidePage(const SetPasswordScreen()),
    ),
    GoRoute(
      path: Routes.profileOnboarding,
      pageBuilder: (context, state) =>
          state.slidePage(const ProfileOnboardingScreen()),
    ),
    GoRoute(
      path: Routes.resetPassword,
      pageBuilder: (context, state) =>
          state.slidePage(const SetPasswordScreen(isRecovery: true)),
    ),
    GoRoute(
      path: Routes.profileSetup,
      pageBuilder: (context, state) =>
          state.slidePage(const PersonalInformationSetupScreen()),
    ),
    GoRoute(
      path: Routes.main,
      pageBuilder: (context, state) => state.navigationPage(
        ProviderScope(
          overrides: [
            matchmakingInitialPageProvider.overrideWithValue(
              MatchmakingPage.discover,
            ),
            matchmakingViewModelProvider.overrideWith(MatchmakingViewModel.new),
          ],
          child: const MatchmakingShellScreen(),
        ),
      ),
    ),
    GoRoute(
      path: Routes.myTrips,
      pageBuilder: (context, state) => state.navigationPage(
        ProviderScope(
          overrides: [
            matchmakingInitialPageProvider.overrideWithValue(
              MatchmakingPage.myTrips,
            ),
            matchmakingViewModelProvider.overrideWith(MatchmakingViewModel.new),
          ],
          child: const MatchmakingShellScreen(),
        ),
      ),
    ),
    GoRoute(
      path: Routes.messages,
      pageBuilder: (context, state) =>
          state.navigationPage(const MessagesScreen()),
    ),
    GoRoute(
      path: Routes.expenseDashboard,
      pageBuilder: (context, state) =>
          state.navigationPage(const ExpenseDashboardScreen()),
    ),
    GoRoute(
      path: '${Routes.createBudget}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        CreateBudgetScreen(tripId: int.parse(state.pathParameters['tripId']!)),
      ),
    ),
    GoRoute(
      path: '${Routes.editBudget}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        EditBudgetScreen(tripId: int.parse(state.pathParameters['tripId']!)),
      ),
    ),
    GoRoute(
      path: '${Routes.addExpense}/:tripId',
      pageBuilder: (context, state) => state.slidePage(
        AddExpenseScreen(tripId: int.parse(state.pathParameters['tripId']!)),
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
          state.navigationPage(const UserAccountScreen()),
    ),
    GoRoute(
      path: '${Routes.publicProfile}/:userId',
      pageBuilder: (context, state) => state.slidePage(
        PublicUserProfileScreen(userId: state.pathParameters['userId']!),
      ),
    ),
    GoRoute(
      path: Routes.identityVerification,
      pageBuilder: (context, state) => state.slidePage(
        IdentityVerificationScreen(
          fromOnboarding: state.uri.queryParameters['onboarding'] == 'true',
        ),
      ),
    ),
    GoRoute(
      path: Routes.settings,
      pageBuilder: (context, state) => state.slidePage(const SettingsScreen()),
    ),
    GoRoute(
      path: Routes.changePassword,
      pageBuilder: (context, state) =>
          state.slidePage(const ChangePasswordScreen()),
    ),
    GoRoute(
      path: Routes.safetyCheckInSettings,
      pageBuilder: (context, state) =>
          state.slidePage(const SafetyCheckInSettingsScreen()),
    ),
    GoRoute(
      path: Routes.blockedUsers,
      pageBuilder: (context, state) =>
          state.slidePage(const BlockedUsersScreen()),
    ),
    GoRoute(
      path: Routes.termsOfService,
      pageBuilder: (context, state) => state.slidePage(const TermsScreen()),
    ),
    GoRoute(
      path: Routes.privacyPolicy,
      pageBuilder: (context, state) =>
          state.slidePage(const PrivacyPolicyScreen()),
    ),
    GoRoute(
      path: Routes.emergencyContacts,
      pageBuilder: (context, state) =>
          state.slidePage(const EmergencyContactsScreen()),
    ),
    GoRoute(
      path: Routes.addEmergencyContact,
      pageBuilder: (context, state) =>
          state.slidePage(const AddEmergencyContactScreen()),
    ),
    GoRoute(
      path: Routes.liveLocation,
      pageBuilder: (context, state) =>
          state.slidePage(const LiveLocationScreen()),
    ),
    GoRoute(
      path: Routes.sos,
      pageBuilder: (context, state) => state.slidePage(const SosScreen()),
    ),
    GoRoute(
      path: Routes.groupCollaboration,
      pageBuilder: (context, state) {
        final tripId = state.uri.queryParameters['tripId'] ?? '';
        final knownRemoved = state.uri.queryParameters['removed'] == 'true';
        return state.slidePage(
          GroupCollaborationScreen(tripId: tripId, knownRemoved: knownRemoved),
        );
      },
    ),
  ],
);
