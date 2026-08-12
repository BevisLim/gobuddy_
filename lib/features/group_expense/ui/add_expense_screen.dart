import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../routing/routes.dart';
import 'expense_form.dart';
import 'widgets/group_expense_app_bar.dart';

class AddExpenseScreen extends StatelessWidget {
  const AddExpenseScreen({super.key, required this.tripId});
  final int tripId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const GroupExpenseAppBar(title: 'Add Expense'),
        body: SafeArea(
          child: ExpenseForm(
            tripId: tripId,
            onSaved: (expenseId) => context.go(
              Uri(
                path: '${Routes.expenseDetails}/$tripId/$expenseId',
                queryParameters: const {
                  'message': 'Expense added successfully',
                },
              ).toString(),
            ),
          ),
        ),
      );
}
