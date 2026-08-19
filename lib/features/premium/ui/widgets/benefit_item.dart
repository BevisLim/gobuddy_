import 'package:flutter/material.dart';

import 'package:flutter_mvvm_riverpod/core/theme/app_colors.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_theme.dart';

class BenefitItem extends StatelessWidget {
  final Widget icon;
  final String title;
  final String description;

  const BenefitItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        icon,
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTheme.title16.copyWith(color: AppColors.mono0),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTheme.body14.copyWith(color: AppColors.mono0),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
