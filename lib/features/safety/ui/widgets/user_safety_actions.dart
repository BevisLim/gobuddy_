import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/routing/routes.dart';
import 'block_user_action.dart';
import 'report_user_action.dart';

Future<void> showUserActionsSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String targetUserId,
  required String targetDisplayName,
  VoidCallback? onBlocked,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('View profile'),
            onTap: () => Navigator.pop(sheetContext, 'profile'),
          ),
          ListTile(
            leading: const Icon(Icons.block, color: Colors.red),
            title: const Text('Block user'),
            onTap: () => Navigator.pop(sheetContext, 'block'),
          ),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: const Text('Report user'),
            onTap: () => Navigator.pop(sheetContext, 'report'),
          ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;

  if (action == 'profile') {
    await context.push(
      '${Routes.publicProfile}/${Uri.encodeComponent(targetUserId)}',
    );
  } else if (action == 'block') {
    await BlockUserAction.show(
      context: context,
      ref: ref,
      targetUserId: targetUserId,
      targetDisplayName: targetDisplayName,
      onBlocked: onBlocked,
    );
  } else if (action == 'report') {
    await ReportUserAction.show(
      context: context,
      ref: ref,
      targetUserId: targetUserId,
      targetDisplayName: targetDisplayName,
    );
  }
}

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
      if (action == 'profile') {
        context.push(
          '${Routes.publicProfile}/${Uri.encodeComponent(targetUserId)}',
        );
      } else if (action == 'block') {
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
        value: 'profile',
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.person_outline),
          title: Text('View profile'),
        ),
      ),
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
