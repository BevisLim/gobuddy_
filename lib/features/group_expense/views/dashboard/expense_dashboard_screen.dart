import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_strings.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/widgets/app_section_header.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../widgets/budget_progress_bar.dart';
import '../../widgets/summary_metric_card.dart';

class ExpenseDashboardScreen extends StatelessWidget {
  const ExpenseDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.dashboard,
                    style: TextStyle(fontWeight: FontWeight.w800)),
                Text('Group expense management',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ]),
          actions: const [
            Padding(
                padding: EdgeInsets.only(right: 16),
                child: CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Text('AF',
                        style: TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w800))))
          ],
        ),
        body: SafeArea(
            child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
              _TripSummaryCard(),
              const SizedBox(height: 24),
              const AppSectionHeader(title: 'Quick Actions'),
              const SizedBox(height: 8),
              _QuickActions(),
              const SizedBox(height: 24),
              AppSectionHeader(
                  title: 'Outstanding Balance',
                  actionLabel: 'View all',
                  onAction: () => Navigator.pushNamed(
                      context, AppRoutes.outstandingBalance)),
              Card(
                  child: ListTile(
                      leading: const CircleAvatar(
                          backgroundColor: Color(0xFFFFF1F2),
                          child: Icon(Icons.balance_outlined,
                              color: AppColors.error)),
                      title: const Text('All caught up for now'),
                      subtitle:
                          const Text('Balances will be calculated in Phase 4'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.pushNamed(
                          context, AppRoutes.outstandingBalance))),
              const SizedBox(height: 24),
              const AppSectionHeader(title: 'Recent Expenses'),
              const Card(
                  child: EmptyState(
                      title: 'No recent expenses',
                      message: AppStrings.noRecentExpenses)),
            ])),
        floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, AppRoutes.addExpense),
            icon: const Icon(Icons.add),
            label: const Text('Add Expense')),
        bottomNavigationBar: NavigationBar(
            selectedIndex: 0,
            onDestinationSelected: (index) {
              if (index == 1) {
                Navigator.pushNamed(context, AppRoutes.outstandingBalance);
              }
              if (index == 2) {
                Navigator.pushNamed(context, AppRoutes.settlementHistory);
              }
              if (index == 3) {
                Navigator.pushNamed(context, AppRoutes.budgetAnalytics);
              }
            },
            destinations: const [
              NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home'),
              NavigationDestination(
                  icon: Icon(Icons.account_balance_wallet_outlined),
                  label: 'Balance'),
              NavigationDestination(
                  icon: Icon(Icons.history), label: 'History'),
              NavigationDestination(
                  icon: Icon(Icons.analytics_outlined), label: 'Analytics'),
            ]),
      );
}

class _TripSummaryCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
      decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [AppColors.darkPrimary, AppColors.primary]),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: .24),
                blurRadius: 20,
                offset: const Offset(0, 10))
          ]),
      padding: const EdgeInsets.all(20),
      child:
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('CURRENT TRIP',
            style: TextStyle(
                color: Colors.white60,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1)),
        SizedBox(height: 6),
        Text('Kuala Lumpur MY',
            style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900)),
        SizedBox(height: 4),
        Text('Jul 19–24, 2025  •  4 travellers',
            style: TextStyle(color: Colors.white70)),
        SizedBox(height: 22),
        Row(children: [
          SummaryMetricCard(
              label: 'Budget', value: 'RM3,000', icon: Icons.savings_outlined),
          SizedBox(width: 8),
          SummaryMetricCard(
              label: 'Spent',
              value: 'RM2,055',
              icon: Icons.receipt_long_outlined),
          SizedBox(width: 8),
          SummaryMetricCard(
              label: 'Left', value: 'RM945', icon: Icons.wallet_outlined),
        ]),
        SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('Budget usage', style: TextStyle(color: Colors.white70)),
          Text('68.5%',
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        SizedBox(height: 8),
        BudgetProgressBar(percentage: 68.5),
      ]));
}

class _QuickActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final actions = [
      ('Expense', Icons.add_card, AppRoutes.addExpense),
      ('Settle', Icons.handshake_outlined, AppRoutes.recordSettlement),
      ('Budget', Icons.savings_outlined, AppRoutes.editBudget),
      ('Balance', Icons.balance_outlined, AppRoutes.outstandingBalance),
      ('History', Icons.history, AppRoutes.settlementHistory),
    ];
    return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
            children: actions
                .map((action) => Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => Navigator.pushNamed(context, action.$3),
                        child: Container(
                            width: 78,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: AppColors.border)),
                            child: Column(children: [
                              Icon(action.$2, color: AppColors.primary),
                              const SizedBox(height: 7),
                              Text(action.$1,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700))
                            ])))))
                .toList()));
  }
}
