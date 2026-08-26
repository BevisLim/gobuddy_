import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:flutter_mvvm_riverpod/core/routing/routes.dart';
import 'package:flutter_mvvm_riverpod/core/environment/env.dart';
import 'package:flutter_mvvm_riverpod/core/permissions/app_permission_service.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/repository/collaboration_repository.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/jitsi_call_screen.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/view_model/group_collaboration_view_model.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/activity_proposal_dialog.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/voice_recorder.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/ui/widgets/voice_message_player.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model.dart';
import 'package:flutter_mvvm_riverpod/features/safety/ui/widgets/block_user_action.dart';
import 'package:flutter_mvvm_riverpod/features/safety/ui/widgets/report_user_action.dart';

class GroupCollaborationScreen extends ConsumerWidget {
  const GroupCollaborationScreen({
    required this.tripId,
    this.knownRemoved = false,
    super.key,
  });
  final String tripId;
  final bool knownRemoved;

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
    if (knownRemoved) return _RemovedGroupScreen(tripId: tripId);
    final workspace = ref.watch(groupCollaborationViewModelProvider(tripId));
    return workspace.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (error, _) => error is CollaborationAccessRemovedException
          ? _RemovedGroupScreen(tripId: tripId)
          : Scaffold(
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

class _RemovedGroupScreen extends ConsumerWidget {
  const _RemovedGroupScreen({required this.tripId});

  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Trip workspace')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.group_remove_outlined, size: 56),
            const SizedBox(height: 16),
            const Text(
              'You are no longer a member of this trip group.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'You can remove this group from Messages. The trip may appear '
              'in Discovery again if it is still accepting travellers.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                final matchmaking = ref.read(
                  matchmakingViewModelProvider.notifier,
                );
                matchmaking.dismissGroup(tripId);
                ref.invalidate(groupCollaborationViewModelProvider(tripId));
                context.go(Routes.messages);
                // Permanently clean up a stale matchmaking membership only
                // after collaboration access has already been revoked.
                ref
                    .read(collaborationRepositoryProvider)
                    .dismissRemovedGroup(tripId)
                    .then((_) => matchmaking.refresh())
                    .catchError((_) {
                      // The local dismissal remains immediate. A later retry
                      // can reconcile if the device was temporarily offline.
                    });
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Remove from Messages'),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Workspace extends ConsumerStatefulWidget {
  const _Workspace({required this.state});
  final GroupCollaborationState state;

  @override
  ConsumerState<_Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends ConsumerState<_Workspace> {
  final Set<String> _seenNotificationIds = {};

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final unreadNotifications = state.unreadNotifications
        .where((item) => !_seenNotificationIds.contains(item.id))
        .toList(growable: false);
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => GroupInfoScreen(state: state),
            ),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Trip workspace'),
              Text('Tap for group info', style: TextStyle(fontSize: 12)),
            ],
          ),
        ),
        actions: [
          IconButton(
            onPressed: () async {
              final newlySeenIds = state.unreadNotifications
                  .map((item) => item.id)
                  .toSet();
              setState(() {
                _seenNotificationIds.addAll(newlySeenIds);
              });
              _showNotifications(context, state.notifications);
              try {
                await viewModel.markCollaborationNotificationsRead();
              } catch (error) {
                if (!context.mounted) return;
                setState(() => _seenNotificationIds.removeAll(newlySeenIds));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Could not mark updates read: $error'),
                  ),
                );
              }
            },
            icon: Badge(
              isLabelVisible: unreadNotifications.isNotEmpty,
              label: Text('${unreadNotifications.length}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Collaboration updates',
          ),
        ],
      ),
      body: _ChatTab(state: state),
    );
  }
}

class GroupInfoScreen extends ConsumerWidget {
  const GroupInfoScreen({required this.state, super.key});

  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Group info')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 44,
            child: Icon(
              Icons.groups,
              size: 44,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          const Center(
            child: Text(
              'Trip workspace',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Center(child: Text('${state.members.length} members')),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _GroupInfoAction(
                icon: Icons.call_outlined,
                label: 'Voice',
                onTap: () => _openInAppCall(
                  context,
                  state.tripId,
                  'voice',
                  () => viewModel.startCall('voice'),
                ),
              ),
              _GroupInfoAction(
                icon: Icons.videocam_outlined,
                label: 'Video',
                onTap: () => _openInAppCall(
                  context,
                  state.tripId,
                  'video',
                  () => viewModel.startCall('video'),
                ),
              ),
              _GroupInfoAction(
                icon: Icons.person_add_alt_1_outlined,
                label: 'Members',
                onTap: () => _openGroupSection(
                  context,
                  'Members',
                  _MembersInfoTab(state: state),
                ),
              ),
              _GroupInfoAction(
                icon: Icons.notifications_outlined,
                label: 'Updates',
                onTap: () => _showNotifications(context, state.notifications),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(),
          _GroupInfoTile(
            icon: Icons.calendar_month_outlined,
            title: 'Timeline & activities',
            subtitle: 'Proposals, polls, RSVPs and activity comments',
            onTap: () => _openGroupSection(
              context,
              'Timeline & activities',
              _TimelineTab(state: state),
            ),
          ),
          _GroupInfoTile(
            icon: Icons.folder_outlined,
            title: 'Files & media',
            subtitle: '${state.files.length} shared file(s)',
            onTap: () => _openGroupSection(
              context,
              'Files & media',
              _FilesTab(state: state),
            ),
          ),
          _GroupInfoTile(
            icon: Icons.history_outlined,
            title: 'Calls',
            subtitle: '${state.calls.length} call(s) in history',
            onTap: () =>
                _openGroupSection(context, 'Calls', _CallsTab(state: state)),
          ),
          const Divider(),
          const Text(
            'Group members',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...state.members
              .take(6)
              .map(
                (member) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: _MemberAvatar(
                    member: member,
                    currentUserId: state.currentUserId,
                    onTap: () => _showMemberSafetyActions(
                      context: context,
                      ref: ref,
                      member: member,
                    ),
                  ),
                  title: Text(member.displayName ?? 'Trip member'),
                  subtitle: Text(
                    member.userId == state.creatorId
                        ? 'Leader'
                        : member.isAdmin
                        ? 'Admin'
                        : 'Member',
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class _GroupInfoAction extends StatelessWidget {
  const _GroupInfoAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      IconButton.filledTonal(onPressed: onTap, icon: Icon(icon)),
      const SizedBox(height: 4),
      Text(label),
    ],
  );
}

class _GroupInfoTile extends StatelessWidget {
  const _GroupInfoTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: onTap,
  );
}

void _openGroupSection(BuildContext context, String title, Widget child) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: child,
      ),
    ),
  );
}

class _MembersInfoTab extends ConsumerWidget {
  const _MembersInfoTab({required this.state});

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
          'Group members',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...state.members.map(
          (member) => ListTile(
            leading: _MemberAvatar(
              member: member,
              currentUserId: state.currentUserId,
              onTap: () => _showMemberSafetyActions(
                context: context,
                ref: ref,
                member: member,
              ),
            ),
            subtitle: Text(
              member.userId == state.creatorId
                  ? 'Leader'
                  : member.isMuted
                  ? 'Muted'
                  : member.isAdmin
                  ? 'Admin'
                  : 'Member',
            ),
            trailing:
                member.userId == state.currentUserId || !state.canManageMembers
                ? null
                : Wrap(
                    spacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _confirmMemberAction(
                          context: context,
                          title: member.isMuted
                              ? 'Unmute member?'
                              : 'Mute member?',
                          message:
                              'This member cannot send chat messages for 30 minutes.',
                          confirmLabel: member.isMuted ? 'Unmute' : 'Mute',
                          onConfirm: () => member.isMuted
                              ? viewModel.unmuteMember(member.userId)
                              : viewModel.muteMember(
                                  member.userId,
                                  const Duration(minutes: 30),
                                ),
                        ),
                        child: Text(member.isMuted ? 'Unmute' : 'Mute'),
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
                      if (state.isCreator && !member.isAdmin)
                        TextButton(
                          onPressed: () => _confirmMemberAction(
                            context: context,
                            title: 'Make admin?',
                            message: 'Admins can mute or remove group members.',
                            confirmLabel: 'Make admin',
                            onConfirm: () => viewModel.makeAdmin(member.userId),
                          ),
                          child: const Text('Make admin'),
                        ),
                      if (state.isCreator && member.isAdmin)
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
                  ),
            title: Row(
              children: [
                Expanded(child: Text(member.displayName ?? 'Trip member')),
                if (member.userId == state.creatorId)
                  const _RoleBadge(label: 'Leader')
                else if (member.isAdmin)
                  const _RoleBadge(label: 'Admin'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemberAvatar extends StatelessWidget {
  const _MemberAvatar({
    required this.member,
    required this.currentUserId,
    required this.onTap,
  });

  final CollaborationMember member;
  final String currentUserId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final displayName = member.displayName?.trim();
    final photoUrl = member.profilePhotoUrl?.trim();
    final avatar = CircleAvatar(
      foregroundImage: photoUrl == null || photoUrl.isEmpty
          ? null
          : NetworkImage(photoUrl),
      child: Text(
        displayName == null || displayName.isEmpty
            ? 'M'
            : displayName[0].toUpperCase(),
      ),
    );
    if (member.userId == currentUserId) return avatar;

    return Tooltip(
      message: 'User options',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: avatar,
      ),
    );
  }
}

Future<void> _showMemberSafetyActions({
  required BuildContext context,
  required WidgetRef ref,
  required CollaborationMember member,
}) async {
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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

  final displayName = member.displayName ?? 'Trip member';
  if (action == 'block') {
    await BlockUserAction.show(
      context: context,
      ref: ref,
      targetUserId: member.userId,
      targetDisplayName: displayName,
    );
  } else if (action == 'report') {
    await ReportUserAction.show(
      context: context,
      ref: ref,
      targetUserId: member.userId,
      targetDisplayName: displayName,
    );
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
  final _messagesController = ScrollController();
  final _voiceRecorder = VoiceRecorder();
  bool _isTyping = false;
  bool _readMarked = false;
  bool _isRecordingVoice = false;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToBottom();
  }

  @override
  void didUpdateWidget(covariant _ChatTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.messages.length != widget.state.messages.length) {
      _scheduleScrollToBottom();
    }
  }

  @override
  void dispose() {
    _voiceRecorder.dispose();
    _messagesController.dispose();
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
            controller: _messagesController,
            padding: const EdgeInsets.all(16),
            children: [
              ...widget.state.messages.map(
                (message) => _MessageBubble(
                  message: message,
                  isMine: message.senderId == widget.state.currentUserId,
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
                IconButton(
                  onPressed: widget.state.isMuted
                      ? null
                      : () => _runWorkspaceAction(
                          context,
                          viewModel.takeAndSharePhoto,
                        ),
                  icon: const Icon(Icons.camera_alt_outlined),
                  tooltip: 'Take photo',
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
                          try {
                            await viewModel.sendMessage(
                              _messageController.text,
                            );
                            _messageController.clear();
                            _isTyping = false;
                          } catch (error) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Could not send message: $error',
                                  ),
                                ),
                              );
                          }
                        },
                  icon: const Icon(Icons.send),
                ),
                IconButton(
                  onPressed: widget.state.isMuted
                      ? null
                      : () => _toggleVoiceRecording(viewModel),
                  icon: Icon(
                    _isRecordingVoice ? Icons.stop_circle : Icons.mic,
                    color: _isRecordingVoice
                        ? Theme.of(context).colorScheme.error
                        : null,
                  ),
                  tooltip: _isRecordingVoice
                      ? 'Stop and send voice message'
                      : 'Record voice message',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _scheduleScrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messagesController.hasClients) return;
      _messagesController.animateTo(
        _messagesController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _toggleVoiceRecording(
    GroupCollaborationViewModel viewModel,
  ) async {
    try {
      if (!_isRecordingVoice) {
        await _voiceRecorder.start();
        if (mounted) setState(() => _isRecordingVoice = true);
        return;
      }
      final bytes = await _voiceRecorder.stop();
      if (mounted) setState(() => _isRecordingVoice = false);
      if (bytes != null) await viewModel.shareVoiceMessage(bytes);
    } catch (error) {
      if (mounted) {
        setState(() => _isRecordingVoice = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record voice message: $error')),
        );
      }
    }
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final TripMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final photoUrl = _messageAttachmentUrl(message.body, '[photo]');
    final voiceUrl = _messageAttachmentUrl(message.body, '[voice]');
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine
                ? colorScheme.primaryContainer
                : colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
          ),
          child: Column(
            crossAxisAlignment: isMine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              if (!isMine)
                Text(
                  message.senderName ?? 'Trip member',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              if (photoUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    photoUrl,
                    height: 220,
                    width: 280,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Photo could not be loaded.'),
                    ),
                  ),
                )
              else if (voiceUrl != null)
                VoiceMessagePlayer(url: voiceUrl)
              else
                Text(message.body),
              const SizedBox(height: 4),
              Text(
                isMine
                    ? '${_shortTime(message.sentAt)} · Seen by ${message.readByCount}'
                    : _shortTime(message.sentAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String? _messageAttachmentUrl(String body, String prefix) {
  if (!body.startsWith(prefix)) return null;
  final url = body.substring(prefix.length).trim();
  return Uri.tryParse(url)?.hasScheme == true ? url : null;
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
        Card(
          color: Theme.of(context).colorScheme.errorContainer,
          child: ListTile(
            leading: Icon(
              Icons.sos,
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
            title: const Text('Emergency SOS'),
            subtitle: const Text(
              'Share your location and call the local emergency number',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.sos),
          ),
        ),
        const SizedBox(height: 12),
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
                        : () => _showEditActivityDialog(
                            context,
                            activity,
                            viewModel,
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

Future<void> _showEditActivityDialog(
  BuildContext context,
  TripActivity activity,
  GroupCollaborationViewModel viewModel,
) async {
  final titleController = TextEditingController(text: activity.title);
  final locationController = TextEditingController(
    text: activity.location ?? '',
  );
  var submitting = false;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Edit activity'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Activity title'),
            ),
            TextField(
              controller: locationController,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 12),
            Text('Time: ${_shortDate(activity.startTime)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: submitting ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: submitting
                ? null
                : () async {
                    setDialogState(() => submitting = true);
                    try {
                      await viewModel.editActivity(
                        activity: activity,
                        title: titleController.text.trim(),
                        startTime: activity.startTime,
                        location: locationController.text.trim().isEmpty
                            ? null
                            : locationController.text.trim(),
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (error) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(
                          dialogContext,
                        ).showSnackBar(SnackBar(content: Text('$error')));
                      }
                    } finally {
                      if (dialogContext.mounted) {
                        setDialogState(() => submitting = false);
                      }
                    }
                  },
            child: Text(submitting ? 'Saving...' : 'Save changes'),
          ),
        ],
      ),
    ),
  );
  titleController.dispose();
  locationController.dispose();
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
                        : () => _openInAppCall(
                            context,
                            state.tripId,
                            call.callType,
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

Future<void> _openInAppCall(
  BuildContext context,
  String tripId,
  String callType,
  Future<TripCall?> Function() action,
) async {
  try {
    await const AppPermissionService().requireCallPermissions(
      withVideo: callType == 'video',
    );
    final call = await action();
    if (call == null || !context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            JitsiCallScreen(tripId: tripId, callType: call.callType),
      ),
    );
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

String _shortTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
