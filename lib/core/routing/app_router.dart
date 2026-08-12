import 'package:flutter/material.dart';

import '../../features/group_expense/views/dashboard/expense_dashboard_screen.dart';

abstract final class AppRoutes {
  static const dashboard = '/';
  static const createBudget = '/budget/create';
  static const editBudget = '/budget/edit';
  static const addExpense = '/expense/add';
  static const expenseDetails = '/expense/details';
  static const editExpense = '/expense/edit';
  static const outstandingBalance = '/balance';
  static const recordSettlement = '/settlement/record';
  static const settlementHistory = '/settlement/history';
  static const budgetAnalytics = '/analytics';
}

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    if (settings.name == AppRoutes.dashboard) {
      return MaterialPageRoute(
          builder: (_) => const ExpenseDashboardScreen(), settings: settings);
    }
    const labels = <String, String>{
      AppRoutes.createBudget: 'Create Trip Budget',
      AppRoutes.editBudget: 'Edit Trip Budget',
      AppRoutes.addExpense: 'Add Expense',
      AppRoutes.expenseDetails: 'Expense Details',
      AppRoutes.editExpense: 'Edit Expense',
      AppRoutes.outstandingBalance: 'Outstanding Balance',
      AppRoutes.recordSettlement: 'Record Settlement',
      AppRoutes.settlementHistory: 'Settlement History',
      AppRoutes.budgetAnalytics: 'Budget Analytics',
    };
    final label = labels[settings.name];
    return MaterialPageRoute(
        builder: (_) =>
            _PhasePlaceholderScreen(title: label ?? 'Page not found'),
        settings: settings);
  }
}

class _PhasePlaceholderScreen extends StatelessWidget {
  const _PhasePlaceholderScreen({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: Center(
            child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    '$title is scheduled for a later implementation phase.',
                    textAlign: TextAlign.center))),
      );
}
