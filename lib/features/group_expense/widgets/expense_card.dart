import 'package:flutter/material.dart';
import '../../../core/utils/money_utils.dart';
import '../models/expense.dart';

class ExpenseCard extends StatelessWidget {
  const ExpenseCard({super.key, required this.expense, this.onTap});
  final Expense expense;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Card(
      child: ListTile(
          onTap: onTap,
          leading: const CircleAvatar(child: Icon(Icons.receipt_outlined)),
          title: Text(expense.title),
          trailing: Text(MoneyUtils.formatCurrency(expense.baseAmount))));
}
