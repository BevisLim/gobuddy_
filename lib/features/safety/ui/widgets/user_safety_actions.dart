import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'block_user_action.dart';
import 'report_user_action.dart';

/// Presents the independent block and report actions in one overflow menu.
class UserSafetyActionsButton extends ConsumerWidget {
  const UserSafetyActionsButton({
    required this.targetUserId,
    required this.targetDisplayName,
    this.onBlocked,
    super.key,
  });

  final String targetUserId;
  final String targetDisplayName;
  final VoidCallback? onBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PopupMenuButton<String>(
        tooltip: 'User safety actions',
        icon: const Icon(Icons.more_vert),
        onSelected: (action) {
          if (action == 'block') {
            BlockUserAction.show(
              context: context,
              ref: ref,
              targetUserId: targetUserId,
              targetDisplayName: targetDisplayName,
              onBlocked: onBlocked,
            );
          } else if (action == 'report') {
            ReportUserAction.show(
              context: context,
              ref: ref,
              targetUserId: targetUserId,
              targetDisplayName: targetDisplayName,
            );
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: 'block',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.block, color: Colors.red),
              title: Text('Block user'),
            ),
          ),
          PopupMenuItem(
            value: 'report',
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.flag_outlined),
              title: Text('Report user'),
            ),
          ),
        ],
      );
}
