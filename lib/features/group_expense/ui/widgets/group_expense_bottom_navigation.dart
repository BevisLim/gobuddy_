import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:flutter_mvvm_riverpod/core/routing/routes.dart';

class GroupExpenseBottomNavigation extends StatelessWidget {
  const GroupExpenseBottomNavigation({
    super.key,
    required this.tripId,
    required this.selectedIndex,
  });

  final int tripId;
  final int selectedIndex;

  @override
  Widget build(BuildContext context) => NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          final route = switch (index) {
            0 => Routes.expenseDashboard,
            1 => '${Routes.outstandingBalance}/$tripId',
            2 => '${Routes.settlementHistory}/$tripId',
            _ => '${Routes.budgetAnalytics}/$tripId',
          };
          if (index != selectedIndex) context.go(route);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.balance_outlined),
            label: 'Balance',
          ),
          NavigationDestination(icon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            label: 'Analytics',
          ),
        ],
      );
}
