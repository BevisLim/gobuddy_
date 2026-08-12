import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader(
      {super.key, required this.title, this.actionLabel, this.onAction});
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Row(children: [
        Expanded(
            child: Text(title,
                style: const TextStyle(
                    color: AppColors.darkPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800))),
        if (actionLabel != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ]);
}
