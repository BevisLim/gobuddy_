import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/user_safety.dart';
import '../../repository/user_safety_repository.dart';

class ReportUserAction {
  const ReportUserAction._();

  static Future<void> show({
    required BuildContext context,
    required WidgetRef ref,
    required String targetUserId,
    required String targetDisplayName,
  }) async {
    final result = await showModalBottomSheet<
        ({
          UserReportReason reason,
          String description,
        })>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ReportUserSheet(targetDisplayName: targetDisplayName),
    );
    if (result == null || !context.mounted) return;

    _showLoading(context);
    try {
      await ref.read(userSafetyRepositoryProvider).reportUser(
            targetUserId: targetUserId,
            reason: result.reason,
            description: result.description,
          );
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Report submitted. Thank you for helping keep GoBuddy safe.',
          ),
        ),
      );
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

class _ReportUserSheet extends StatefulWidget {
  const _ReportUserSheet({required this.targetDisplayName});
  final String targetDisplayName;

  @override
  State<_ReportUserSheet> createState() => _ReportUserSheetState();
}

class _ReportUserSheetState extends State<_ReportUserSheet> {
  final _description = TextEditingController();
  UserReportReason? _reason;

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report ${widget.targetDisplayName}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              const Text('Select the reason that best describes the issue.'),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserReportReason>(
                initialValue: _reason,
                decoration: const InputDecoration(
                  labelText: 'Reason',
                  border: OutlineInputBorder(),
                ),
                items: UserReportReason.values
                    .map((reason) => DropdownMenuItem(
                          value: reason,
                          child: Text(reason.label),
                        ))
                    .toList(),
                onChanged: (reason) => setState(() => _reason = reason),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLength: 1000,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Additional details (optional)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _reason == null
                      ? null
                      : () => Navigator.pop(
                            context,
                            (
                              reason: _reason!,
                              description: _description.text,
                            ),
                          ),
                  child: const Text('Submit report'),
                ),
              ),
            ],
          ),
        ),
      );
}
