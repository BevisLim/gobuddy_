import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_mvvm_riverpod/core/environment/env.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/view_model/group_collaboration_view_model.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/activity_proposal_dialog.dart';

class GroupCollaborationScreen extends ConsumerWidget {
  const GroupCollaborationScreen({required this.tripId, super.key});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tripId.isEmpty || !Env.hasSupabase) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip workspace')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'The real group workspace needs a trip ID and Supabase configuration.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final workspace = ref.watch(groupCollaborationViewModelProvider(tripId));
    return workspace.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: const Text('Trip workspace')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$error'),
          ),
        ),
      ),
      data: (state) => _Workspace(state: state),
    );
  }
}

class _Workspace extends ConsumerWidget {
  const _Workspace({required this.state});
  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip workspace'),
          actions: [
            IconButton(
              onPressed: () => _showNotifications(context, state.notifications),
              icon: Badge(
                isLabelVisible: state.notifications.isNotEmpty,
                label: Text('${state.notifications.length}'),
                child: const Icon(Icons.notifications_outlined),
              ),
              tooltip: 'Collaboration updates',
            ),
            IconButton(
              onPressed: () =>
                  _run(context, () => viewModel.startCall('voice')),
              icon: const Icon(Icons.call),
              tooltip: 'Voice call',
            ),
            IconButton(
              onPressed: () =>
                  _run(context, () => viewModel.startCall('video')),
              icon: const Icon(Icons.videocam),
              tooltip: 'Video call',
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Chat'),
              Tab(text: 'Timeline'),
              Tab(text: 'Files'),
              Tab(text: 'Calls'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChatTab(state: state),
            _TimelineTab(state: state),
            _FilesTab(state: state),
            _CallsTab(state: state),
          ],
        ),
      ),
    );
  }

  Future<void> _run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    }
  }
}

class _ChatTab extends ConsumerStatefulWidget {
  const _ChatTab({required this.state});
  final GroupCollaborationState state;

  @override
  ConsumerState<_ChatTab> createState() => _ChatTabState();
}

class _ChatTabState extends ConsumerState<_ChatTab> {
  final _messageController = TextEditingController();
  bool _isTyping = false;
  bool _readMarked = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(widget.state.tripId).notifier,
    );
    if (!_readMarked && widget.state.messages.isNotEmpty) {
      _readMarked = true;
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => viewModel.markMessagesRead(),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ...widget.state.messages.map(
                (message) => Card(
                  child: ListTile(
                    title: Text(
                      message.senderId == widget.state.currentUserId
                          ? 'You'
                          : (message.senderName ?? 'Trip member'),
                    ),
                    subtitle: Text(
                      message.senderId == widget.state.currentUserId
                          ? '${message.body}\nSeen by ${message.readByCount} member(s)'
                          : message.body,
                    ),
                    isThreeLine: message.senderId == widget.state.currentUserId,
                  ),
                ),
              ),
              const Text(
                'Member Management',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...widget.state.members
                  .where(
                    (member) => member.userId != widget.state.currentUserId,
                  )
                  .map(
                    (member) => ListTile(
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(member.displayName ?? 'Trip member'),
                          ),
                          if (member.userId == widget.state.creatorId)
                            const _RoleBadge(label: 'Creator')
                          else if (member.isAdmin)
                            const _RoleBadge(label: 'Admin'),
                        ],
                      ),
                      subtitle: member.isMuted
                          ? const Text('Muted for 30 minutes')
                          : const Text('Trip member'),
                      trailing: widget.state.canManageMembers
                          ? Wrap(
                              children: [
                                TextButton(
                                  onPressed: () => _confirmMemberAction(
                                    context: context,
                                    title: member.isMuted
                                        ? 'Unmute member?'
                                        : 'Mute member?',
                                    message:
                                        'This member cannot send chat messages for 30 minutes.',
                                    confirmLabel: member.isMuted
                                        ? 'Unmute'
                                        : 'Mute',
                                    onConfirm: () => member.isMuted
                                        ? viewModel.unmuteMember(member.userId)
                                        : viewModel.muteMember(
                                            member.userId,
                                            const Duration(minutes: 30),
                                          ),
                                  ),
                                  child: Text(
                                    member.isMuted ? 'Unmute' : 'Mute',
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _confirmMemberAction(
                                    context: context,
                                    title: 'Remove member?',
                                    message:
                                        'They will lose access to this trip workspace.',
                                    confirmLabel: 'Remove',
                                    isDestructive: true,
                                    onConfirm: () =>
                                        viewModel.removeMember(member.userId),
                                  ),
                                  child: const Text('Remove'),
                                ),
                                if (widget.state.isCreator && !member.isAdmin)
                                  TextButton(
                                    onPressed: () => _confirmMemberAction(
                                      context: context,
                                      title: 'Make admin?',
                                      message:
                                          'Admins can mute or remove group members.',
                                      confirmLabel: 'Make admin',
                                      onConfirm: () =>
                                          viewModel.makeAdmin(member.userId),
                                    ),
                                    child: const Text('Make admin'),
                                  ),
                                if (widget.state.isCreator && member.isAdmin)
                                  TextButton(
                                    onPressed: () => _confirmMemberAction(
                                      context: context,
                                      title: 'Remove admin?',
                                      message:
                                          'This member will remain in the group but lose admin permissions.',
                                      confirmLabel: 'Remove admin',
                                      onConfirm: () =>
                                          viewModel.removeAdmin(member.userId),
                                    ),
                                    child: const Text('Remove admin'),
                                  ),
                              ],
                            )
                          : null,
                    ),
                  ),
              if (widget.state.typingMemberNames.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${widget.state.typingMemberNames.join(', ')} ${widget.state.typingMemberNames.length == 1 ? 'is' : 'are'} typing…',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: () =>
                      _runWorkspaceAction(context, viewModel.pickAndShareFile),
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Share file',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    onChanged: (value) {
                      final typing = value.trim().isNotEmpty;
                      if (typing != _isTyping) {
                        _isTyping = typing;
                        viewModel.setTyping(typing);
                      }
                    },
                    enabled: !widget.state.isMuted,
                    decoration: const InputDecoration(
                      hintText: 'Message group',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: widget.state.isMuted
                      ? null
                      : () async {
                          await viewModel.sendMessage(_messageController.text);
                          _messageController.clear();
                          _isTyping = false;
                        },
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({required this.state});
  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => ActivityProposalDialog(
              onPropose: (title, location) => viewModel.proposeActivity(
                title: title,
                location: location,
                startTime: DateTime.now().add(const Duration(days: 1)),
              ),
              onCreatePoll: (question, options) => viewModel.createActivityPoll(
                question: question,
                options: options,
              ),
            ),
          ),
          icon: const Icon(Icons.add),
          label: const Text('Propose activity'),
        ),
        const SizedBox(height: 12),
        _ActivityHistoryPanel(notifications: state.notifications),
        const SizedBox(height: 12),
        ...state.activities.map(
          (activity) => Card(
            child: ListTile(
              title: Text(activity.title),
              subtitle: Text(
                '${activity.startTime}\n${state.comments.where((comment) => comment.activityId == activity.id).length} comment(s) · ${_rsvpSummary(state, activity.id)}',
              ),
              isThreeLine: true,
              trailing: Wrap(
                children: [
                  IconButton(
                    onPressed: () =>
                        _showComments(context, state, activity, viewModel),
                    icon: const Icon(Icons.comment_outlined),
                    tooltip: 'Activity comments',
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Your RSVP',
                    onSelected: (status) => _runWorkspaceAction(
                      context,
                      () => viewModel.setActivityRsvp(
                        activityId: activity.id,
                        status: status,
                      ),
                    ),
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'going', child: Text('Going')),
                      PopupMenuItem(value: 'maybe', child: Text('Maybe')),
                      PopupMenuItem(
                        value: 'not_going',
                        child: Text('Not going'),
                      ),
                    ],
                    child: Chip(label: Text(_currentRsvp(state, activity.id))),
                  ),
                  IconButton(
                    onPressed: () => viewModel.togglePin(activity),
                    icon: Icon(
                      activity.isPinned
                          ? Icons.push_pin
                          : Icons.push_pin_outlined,
                    ),
                    tooltip: 'Pin activity',
                  ),
                  IconButton(
                    onPressed: activity.isLocked && !state.isCreator
                        ? null
                        : () => viewModel.editActivity(
                            activity: activity,
                            title: activity.title,
                            startTime: activity.startTime,
                            location: activity.location,
                          ),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit activity',
                  ),
                  if (state.isCreator)
                    IconButton(
                      onPressed: () => viewModel.toggleLock(activity),
                      icon: Icon(
                        activity.isLocked
                            ? Icons.lock
                            : Icons.lock_open_outlined,
                      ),
                      tooltip: 'Lock activity',
                    ),
                ],
              ),
            ),
          ),
        ),
        const Text(
          'Activity Polls',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        ...state.polls.map(
          (poll) => Card(
            child: Column(
              children: poll.options
                  .map(
                    (option) => ListTile(
                      title: Text(option.label),
                      subtitle: Text('${option.voterIds.length} votes'),
                      trailing: FilledButton(
                        onPressed: () => viewModel.castVote(poll.id, option.id),
                        child: const Text('Vote'),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}

void _showNotifications(
  BuildContext context,
  List<CollaborationNotification> notifications,
) {
  showModalBottomSheet<void>(
    context: context,
    builder: (_) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Live collaboration updates',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (notifications.isEmpty)
            const ListTile(title: Text('No updates yet.')),
          ...notifications.map(
            (item) => ListTile(
              leading: const Icon(Icons.notifications_active_outlined),
              title: Text(item.summary),
              subtitle: Text(item.createdAt.toString()),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showComments(
  BuildContext context,
  GroupCollaborationState state,
  TripActivity activity,
  GroupCollaborationViewModel viewModel,
) async {
  final controller = TextEditingController();
  final comments = state.comments
      .where((comment) => comment.activityId == activity.id)
      .toList();
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        16,
        16,
        MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Comments: ${activity.title}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (comments.isEmpty) const Text('No comments yet.'),
          ...comments.map(
            (comment) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(comment.body),
              subtitle: Text(comment.createdAt.toString()),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'Add a comment'),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: () async {
                  await viewModel.addActivityComment(
                    activityId: activity.id,
                    body: controller.text,
                  );
                  if (sheetContext.mounted) Navigator.pop(sheetContext);
                },
              ),
            ],
          ),
        ],
      ),
    ),
  );
  controller.dispose();
}

class _FilesTab extends ConsumerWidget {
  const _FilesTab({required this.state});
  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: viewModel.pickAndShareFile,
          icon: const Icon(Icons.upload_file),
          label: const Text('Share files'),
        ),
        ...state.files.map(
          (file) => ListTile(
            title: Text(file.name),
            subtitle: Text(
              '${file.uploadedBy == state.currentUserId ? 'You' : (file.uploadedByName ?? 'Trip member')} · ${_shortDate(file.createdAt)} · ${_fileSize(file.sizeBytes)}',
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  icon: const Icon(Icons.open_in_new),
                  onPressed: () => launchUrl(
                    Uri.parse(file.url),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                if (file.uploadedBy == state.currentUserId ||
                    state.canManageMembers)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete file',
                    onPressed: () => _confirmMemberAction(
                      context: context,
                      title: 'Delete file?',
                      message:
                          '${file.name} will no longer be available to the group.',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                      onConfirm: () => viewModel.deleteFile(file),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CallsTab extends ConsumerWidget {
  const _CallsTab({required this.state});

  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Call history',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        const Text('Join any group call in the shared Jitsi room.'),
        const SizedBox(height: 12),
        if (state.calls.isEmpty)
          const Card(
            child: ListTile(
              leading: Icon(Icons.call_outlined),
              title: Text('No calls yet'),
              subtitle: Text('Start a voice or video call from the top bar.'),
            ),
          ),
        ...state.calls.map(
          (call) => Card(
            child: ListTile(
              leading: Icon(call.isVideo ? Icons.videocam : Icons.call),
              title: Text('${call.isVideo ? 'Video' : 'Voice'} call'),
              subtitle: Text(
                '${call.initiatedBy == state.currentUserId ? 'You' : (call.initiatedByName ?? 'Trip member')} · ${_shortDate(call.createdAt)} · ${call.status}',
              ),
              trailing: Wrap(
                children: [
                  FilledButton(
                    onPressed: call.status == 'ended'
                        ? null
                        : () => _runWorkspaceAction(
                            context,
                            () => viewModel.joinCall(call),
                          ),
                    child: Text(call.status == 'ended' ? 'Ended' : 'Join'),
                  ),
                  if (call.initiatedBy == state.currentUserId ||
                      state.canManageMembers)
                    IconButton(
                      tooltip: 'End call',
                      onPressed: call.status == 'ended'
                          ? null
                          : () => _confirmMemberAction(
                              context: context,
                              title: 'End call?',
                              message:
                                  'This marks the call as ended in group history.',
                              confirmLabel: 'End call',
                              isDestructive: true,
                              onConfirm: () => viewModel.endCall(call),
                            ),
                      icon: const Icon(Icons.call_end),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityHistoryPanel extends StatelessWidget {
  const _ActivityHistoryPanel({required this.notifications});

  final List<CollaborationNotification> notifications;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history),
              SizedBox(width: 8),
              Text(
                'Activity history',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (notifications.isEmpty)
            const Text(
              'Votes, edits, member actions, and files will appear here.',
            ),
          ...notifications
              .take(5)
              .map(
                (event) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.bolt_outlined),
                  title: Text(event.summary),
                  subtitle: Text(_shortDate(event.createdAt)),
                ),
              ),
        ],
      ),
    ),
  );
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: const TextStyle(fontSize: 12)),
  );
}

Future<void> _confirmMemberAction({
  required BuildContext context,
  required String title,
  required String message,
  required String confirmLabel,
  required Future<void> Function() onConfirm,
  bool isDestructive = false,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: isDestructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(dialogContext).colorScheme.error,
                )
              : null,
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _runWorkspaceAction(context, onConfirm);
  }
}

Future<void> _runWorkspaceAction(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }
}

String _shortDate(DateTime value) =>
    '${value.day}/${value.month}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

String _currentRsvp(GroupCollaborationState state, String activityId) {
  final ownRsvp = state.rsvps
      .where(
        (rsvp) =>
            rsvp.activityId == activityId && rsvp.userId == state.currentUserId,
      )
      .map((rsvp) => rsvp.status)
      .firstOrNull;
  return switch (ownRsvp) {
    'going' => 'Going',
    'maybe' => 'Maybe',
    'not_going' => 'Not going',
    _ => 'RSVP',
  };
}

String _rsvpSummary(GroupCollaborationState state, String activityId) {
  final rsvps = state.rsvps.where((rsvp) => rsvp.activityId == activityId);
  final going = rsvps.where((rsvp) => rsvp.status == 'going').length;
  final maybe = rsvps.where((rsvp) => rsvp.status == 'maybe').length;
  final notGoing = rsvps.where((rsvp) => rsvp.status == 'not_going').length;
  return '$going going · $maybe maybe · $notGoing not going';
}

String _fileSize(int? bytes) {
  if (bytes == null) return 'size unavailable';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
