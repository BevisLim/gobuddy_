import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class BudgetProgressBar extends StatelessWidget {
  const BudgetProgressBar({super.key, required this.percentage});
  final double percentage;
  @override
  Widget build(BuildContext context) {
    final color = percentage > 100
        ? AppColors.error
        : percentage >= 85
            ? AppColors.warning
            : AppColors.success;
    return ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(
            minHeight: 9,
            value: (percentage / 100).clamp(0, 1),
            color: color,
            backgroundColor: AppColors.border));
  }
}
