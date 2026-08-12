import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'expense_form.dart';
import 'widgets/group_expense_app_bar.dart';

class EditExpenseScreen extends StatelessWidget {
  const EditExpenseScreen({
    super.key,
    required this.tripId,
    required this.expenseId,
  });
  final int tripId;
  final int expenseId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: const GroupExpenseAppBar(title: 'Edit Expense'),
        body: SafeArea(
          child: ExpenseForm(
            tripId: tripId,
            expenseId: expenseId,
            onSaved: (_) => context.pop(),
          ),
        ),
      );
}
