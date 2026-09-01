import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../repository/user_safety_repository.dart';

class BlockUserAction {
  const BlockUserAction._();

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required String targetUserId,
    required String targetDisplayName,
    required bool isBlocked,
    VoidCallback? onBlocked,
    VoidCallback? onUnblocked,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          isBlocked
              ? 'Unblock $targetDisplayName?'
              : 'Block $targetDisplayName?',
        ),
        content: Text(
          isBlocked
              ? '$targetDisplayName will be able to interact with you again.'
              : '$targetDisplayName will no longer be able to send you trip '
                  'requests or interact with you. They will not be notified.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: isBlocked
                ? null
                : FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(isBlocked ? 'Unblock' : 'Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    _showLoading(context);
    try {
      final repository = ref.read(userSafetyRepositoryProvider);
      if (isBlocked) {
        await repository.unblockUser(targetUserId);
      } else {
        await repository.blockUser(targetUserId);
      }
      ref.invalidate(isUserBlockedProvider(targetUserId));
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$targetDisplayName has been '
            '${isBlocked ? 'unblocked' : 'blocked'}.',
          ),
        ),
      );
      if (isBlocked) {
        onUnblocked?.call();
      } else {
        onBlocked?.call();
      }
    } catch (error) {
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    }
  }

  static void _showLoading(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
  }
}
