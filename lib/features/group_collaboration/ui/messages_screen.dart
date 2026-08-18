import 'package:flutter/material.dart';

import 'package:flutter_mvvm_riverpod/core/theme/app_colors.dart';
import 'package:flutter_mvvm_riverpod/core/theme/app_theme.dart';
import 'package:flutter_mvvm_riverpod/features/common/ui/widgets/app_module_navigation.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Messages', style: AppTheme.title20),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 56,
                color: AppColors.brandSurface,
              ),
              const SizedBox(height: 16),
              Text('No messages yet', style: AppTheme.title20),
              const SizedBox(height: 8),
              Text(
                'Your group conversations will appear here.',
                textAlign: TextAlign.center,
                style: AppTheme.body16.copyWith(
                  color: AppColors.brandTextMuted,
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const AppModuleNavigation(selectedIndex: 2),
    );
  }
}
