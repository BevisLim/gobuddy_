import 'dart:io';
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TravellerAvatar extends StatelessWidget {
  const TravellerAvatar(
      {super.key, required this.initials, this.imagePath, this.radius = 22});
  final String initials;
  final String? imagePath;
  final double radius;
  @override
  Widget build(BuildContext context) => CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withValues(alpha: .12),
      foregroundImage: imagePath == null ? null : FileImage(File(imagePath!)),
      child: Text(initials,
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.w800)));
}
