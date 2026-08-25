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
      length: 3,
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ChatTab(state: state),
            _TimelineTab(state: state),
            _FilesTab(state: state),
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
                    subtitle: Text(message.body),
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
                      title: Text(member.displayName ?? 'Trip member'),
                      trailing: widget.state.canManageMembers
                          ? Wrap(
                              children: [
                                TextButton(
                                  onPressed: () => viewModel.muteMember(
                                    member.userId,
                                    const Duration(minutes: 30),
                                  ),
                                  child: const Text('Mute'),
                                ),
                                TextButton(
                                  onPressed: () =>
                                      viewModel.removeMember(member.userId),
                                  child: const Text('Remove'),
                                ),
                                if (widget.state.isCreator)
                                  TextButton(
                                    onPressed: () =>
                                        viewModel.makeAdmin(member.userId),
                                    child: const Text('Make admin'),
                                  ),
                              ],
                            )
                          : null,
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
                  onPressed: viewModel.pickAndShareFile,
                  icon: const Icon(Icons.attach_file),
                  tooltip: 'Share file',
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
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
        ...state.activities.map(
          (activity) => Card(
            child: ListTile(
              title: Text(activity.title),
              subtitle: Text(
                '${activity.startTime}\n${state.comments.where((comment) => comment.activityId == activity.id).length} comment(s)',
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
            trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(
                Uri.parse(file.url),
                mode: LaunchMode.externalApplication,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
