import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_mvvm_riverpod/core/environment/env.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/group_collaboration_preview_screen.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/view_model/group_collaboration_view_model.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/activity_proposal_dialog.dart';

class GroupCollaborationScreen extends ConsumerWidget {
  const GroupCollaborationScreen({required this.tripId, super.key});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (tripId.isEmpty || !Env.hasSupabase) {
      return GroupCollaborationPreviewScreen(tripId: tripId);
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
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => ref.invalidate(
                  groupCollaborationViewModelProvider(tripId),
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ]),
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
    final viewModel =
        ref.read(groupCollaborationViewModelProvider(state.tripId).notifier);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip workspace'),
          actions: [
            IconButton(
                onPressed: () =>
                    _run(context, () => viewModel.startCall('voice')),
                icon: const Icon(Icons.call),
                tooltip: 'Voice call'),
            IconButton(
                onPressed: () =>
                    _run(context, () => viewModel.startCall('video')),
                icon: const Icon(Icons.videocam),
                tooltip: 'Video call'),
          ],
          bottom: const TabBar(tabs: [
            Tab(text: 'Chat'),
            Tab(text: 'Timeline'),
            Tab(text: 'Files')
          ]),
        ),
        body: TabBarView(children: [
          _ChatTab(state: state),
          _TimelineTab(state: state),
          _FilesTab(state: state),
        ]),
      ),
    );
  }

  Future<void> _run(
      BuildContext context, Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$error')));
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
        groupCollaborationViewModelProvider(widget.state.tripId).notifier);
    return Column(children: [
      Expanded(
          child: ListView(padding: const EdgeInsets.all(16), children: [
        ...widget.state.messages.map((message) => Card(
            child: ListTile(
                title: Text(message.senderId), subtitle: Text(message.body)))),
        const Text('Member Management',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ...widget.state.members
            .where((member) => member.userId != widget.state.currentUserId)
            .map((member) => ListTile(
                  title: Text(member.userId),
                  trailing: widget.state.isCreator
                      ? Wrap(children: [
                          TextButton(
                              onPressed: () => viewModel.muteMember(
                                  member.userId, const Duration(minutes: 30)),
                              child: const Text('Mute')),
                          TextButton(
                              onPressed: () =>
                                  viewModel.removeMember(member.userId),
                              child: const Text('Remove')),
                        ])
                      : null,
                )),
      ])),
      SafeArea(
          top: false,
          child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                IconButton(
                    onPressed: viewModel.pickAndShareFile,
                    icon: const Icon(Icons.attach_file),
                    tooltip: 'Share file'),
                Expanded(
                    child: TextField(
                        controller: _messageController,
                        enabled: !widget.state.isMuted,
                        decoration: const InputDecoration(
                            hintText: 'Message group',
                            border: OutlineInputBorder()))),
                IconButton(
                    onPressed: widget.state.isMuted
                        ? null
                        : () async {
                            await viewModel
                                .sendMessage(_messageController.text);
                            _messageController.clear();
                          },
                    icon: const Icon(Icons.send)),
              ]))),
    ]);
  }
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({required this.state});
  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel =
        ref.read(groupCollaborationViewModelProvider(state.tripId).notifier);
    return ListView(padding: const EdgeInsets.all(16), children: [
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
      ...state.activities.map((activity) => Card(
              child: ListTile(
            title: Text(activity.title),
            subtitle: Text('${activity.startTime}'),
            trailing: Wrap(children: [
              IconButton(
                  onPressed: () => viewModel.togglePin(activity),
                  icon: Icon(activity.isPinned
                      ? Icons.push_pin
                      : Icons.push_pin_outlined),
                  tooltip: 'Pin activity'),
              IconButton(
                  onPressed: activity.isLocked && !state.isCreator
                      ? null
                      : () => viewModel.editActivity(
                          activity: activity,
                          title: activity.title,
                          startTime: activity.startTime,
                          location: activity.location),
                  icon: const Icon(Icons.edit_outlined),
                  tooltip: 'Edit activity'),
              if (state.isCreator)
                IconButton(
                    onPressed: () => viewModel.toggleLock(activity),
                    icon: Icon(activity.isLocked
                        ? Icons.lock
                        : Icons.lock_open_outlined),
                    tooltip: 'Lock activity'),
            ]),
          ))),
      const Text('Activity Polls',
          style: TextStyle(fontWeight: FontWeight.bold)),
      ...state.polls.map((poll) => Card(
          child: Column(
              children: poll.options
                  .map((option) => ListTile(
                        title: Text(option.label),
                        subtitle: Text('${option.voterIds.length} votes'),
                        trailing: FilledButton(
                            onPressed: () =>
                                viewModel.castVote(poll.id, option.id),
                            child: const Text('Vote')),
                      ))
                  .toList()))),
    ]);
  }
}

class _FilesTab extends ConsumerWidget {
  const _FilesTab({required this.state});
  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel =
        ref.read(groupCollaborationViewModelProvider(state.tripId).notifier);
    return ListView(padding: const EdgeInsets.all(16), children: [
      FilledButton.icon(
          onPressed: viewModel.pickAndShareFile,
          icon: const Icon(Icons.upload_file),
          label: const Text('Share files')),
      ...state.files.map((file) => ListTile(
          title: Text(file.name),
          trailing: IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => launchUrl(Uri.parse(file.url),
                  mode: LaunchMode.externalApplication)))),
    ]);
  }
}
