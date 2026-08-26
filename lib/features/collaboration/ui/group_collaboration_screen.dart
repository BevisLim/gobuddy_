import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
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
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _TripTimelineScreen(state: state),
              ),
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
    final sharedActivity = _sharedActivityParts(message.body);
    final systemMessage = message.body.startsWith('[system]')
        ? message.body.substring('[system]'.length)
        : null;
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
              else if (sharedActivity != null)
                _SharedActivityPreview(parts: sharedActivity)
              else if (systemMessage != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.info_outline, size: 17),
                    const SizedBox(width: 7),
                    Flexible(child: Text(systemMessage)),
                  ],
                )
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

List<String>? _sharedActivityParts(String body) {
  if (!body.startsWith('[activity_share]')) return null;
  final parts = body.substring('[activity_share]'.length).split('|');
  return parts.length >= 4 ? parts : null;
}

class _SharedActivityPreview extends StatelessWidget {
  const _SharedActivityPreview({required this.parts});
  final List<String> parts;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse(parts[2])?.toLocal();
    return Container(
      width: 280,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_outlined, size: 17),
              SizedBox(width: 6),
              Text(
                'Shared activity',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            parts[1],
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          if (date != null) Text('${_monthDay(date)} at ${_clockTime(date)}'),
          if (parts[3].isNotEmpty) Text(parts[3]),
        ],
      ),
    );
  }
}

class _TripTimelineScreen extends ConsumerStatefulWidget {
  const _TripTimelineScreen({required this.state});

  final GroupCollaborationState state;

  @override
  ConsumerState<_TripTimelineScreen> createState() =>
      _TripTimelineScreenState();
}

class _TripTimelineScreenState extends ConsumerState<_TripTimelineScreen> {
  int _selectedDay = 0;

  List<DateTime> _days(GroupCollaborationState state) {
    final values = <DateTime>[...state.timelineDays];
    for (final activity in state.activities) {
      final day = DateTime(
        activity.startTime.year,
        activity.startTime.month,
        activity.startTime.day,
      );
      if (!values.contains(day)) values.add(day);
    }
    values.sort();
    if (values.isEmpty) {
      final now = DateTime.now();
      values.add(DateTime(now.year, now.month, now.day));
    }
    return values;
  }

  GroupCollaborationViewModel get _viewModel => ref.read(
    groupCollaborationViewModelProvider(widget.state.tripId).notifier,
  );

  @override
  Widget build(BuildContext context) {
    final workspace = ref.watch(
      groupCollaborationViewModelProvider(widget.state.tripId),
    );
    final state = switch (workspace) {
      AsyncData<GroupCollaborationState>(:final value) => value,
      _ => widget.state,
    };
    final days = _days(state);
    final selectedIndex = _selectedDay.clamp(0, days.length - 1);
    final selectedDate = days[selectedIndex];
    final activities = [...state.activities]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final selectedActivities = activities
        .where((activity) => _sameDay(activity.startTime, selectedDate))
        .toList();
    const purple = Color(0xFF7C3AED);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        titleSpacing: 0,
        title: Text(
          'Bali Summer Trip - ${days.length} ${days.length == 1 ? 'day' : 'days'}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      body: Column(
        children: [
          SizedBox(
            height: 68,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: days.length + 1,
              itemBuilder: (context, index) {
                if (index == days.length) {
                  return InkWell(
                    onTap: () async {
                      final nextDay = days.last.add(const Duration(days: 1));
                      try {
                        await _viewModel.addTimelineDay(nextDay);
                        if (mounted) setState(() => _selectedDay = days.length);
                      } catch (error) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('$error')),
                          );
                        }
                      }
                    },
                    child: const SizedBox(
                      width: 88,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline),
                          SizedBox(height: 3),
                          Text(
                            'Add Day',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                final selected = index == selectedIndex;
                return InkWell(
                  onTap: () => setState(() => _selectedDay = index),
                  child: Container(
                    width: 76,
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: selected ? purple : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Day ${index + 1}',
                          style: TextStyle(
                            color: selected ? purple : null,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          _monthDay(days[index]),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: selectedActivities.isEmpty && state.polls.isEmpty
                ? const Center(child: Text('No activities for this day yet.'))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 96),
                    children: [
                      ...selectedActivities.indexed.map(
                        (entry) => _TimelineActivityItem(
                          state: state,
                          activity: entry.$2,
                          isLast: entry.$1 == selectedActivities.length - 1,
                        ),
                      ),
                      if (selectedActivities.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text('No activities for this day yet.'),
                          ),
                        ),
                      if (state.polls.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.only(top: 8, bottom: 8),
                          child: Text(
                            'Activity Polls',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        ...state.polls.map(
                          (poll) => _TimelinePollCard(
                            state: state,
                            poll: poll,
                          ),
                        ),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF281950),
        foregroundColor: Colors.white,
        onPressed: () => _showAddActivity(selectedDate),
        icon: const Icon(Icons.add),
        label: const Text('Add Activity'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 3,
        onDestinationSelected: (index) {
          final route = switch (index) {
            0 || 1 => Routes.main,
            2 => Routes.myTrips,
            3 => Routes.messages,
            _ => Routes.userAccount,
          };
          context.go(route);
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.search_rounded),
            label: 'Discover',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_outlined),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Messages',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Future<void> _showAddActivity(DateTime day) => showDialog<void>(
    context: context,
    builder: (_) => ActivityProposalDialog(
      onPropose: (title, location) => _viewModel.proposeActivity(
        title: title,
        location: location,
        startTime: day.add(const Duration(hours: 12, minutes: 30)),
      ),
      onCreatePoll: (question, options) =>
          _viewModel.createActivityPoll(question: question, options: options),
    ),
  );
}

class _TimelinePollCard extends ConsumerWidget {
  const _TimelinePollCard({required this.state, required this.poll});

  final GroupCollaborationState state;
  final ActivityPoll poll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    final totalVotes = poll.options.fold<int>(
      0,
      (total, option) => total + option.voterIds.length,
    );
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.how_to_vote_outlined, size: 19),
                SizedBox(width: 7),
                Text(
                  'Group vote',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              poll.question,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ...poll.options.map((option) {
              final selected = option.voterIds.contains(state.currentUserId);
              final percentage = totalVotes == 0
                  ? 0.0
                  : option.voterIds.length / totalVotes;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => _runWorkspaceAction(
                    context,
                    () => viewModel.castVote(poll.id, option.id),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              size: 19,
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(option.label)),
                            Text('${option.voterIds.length}'),
                          ],
                        ),
                        const SizedBox(height: 7),
                        LinearProgressIndicator(
                          value: percentage,
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            Text(
              '$totalVotes ${totalVotes == 1 ? 'vote' : 'votes'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimelineActivityItem extends ConsumerWidget {
  const _TimelineActivityItem({
    required this.state,
    required this.activity,
    required this.isLast,
  });

  final GroupCollaborationState state;
  final TripActivity activity;
  final bool isLast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    final inProgress = activity.startTime.isBefore(DateTime.now());
    final accent = inProgress
        ? const Color(0xFF7C3AED)
        : const Color(0xFFF59E0B);
    final creator = state.members
        .where((member) => member.userId == state.creatorId)
        .firstOrNull;
    final organizer = creator?.displayName ?? 'Trip organiser';

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 34,
            child: Column(
              children: [
                const SizedBox(height: 18),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      color: const Color(0xFFD8CFF0),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.only(bottom: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: activity.isPinned
                    ? const BorderSide(color: Color(0xFF7C3AED), width: 1.5)
                    : BorderSide(color: Theme.of(context).dividerColor),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _TimelinePill(
                          label: inProgress
                              ? 'In Progress'
                              : 'Upcoming',
                          foreground: inProgress
                              ? const Color(0xFF6D28D9)
                              : const Color(0xFFB45309),
                          background: inProgress
                              ? const Color(0xFFF1EAFE)
                              : const Color(0xFFFFF3D6),
                        ),
                        const Spacer(),
                        _TimelinePill(
                          label: _clockTime(activity.startTime),
                          foreground: const Color(0xFF7C3AED),
                          background: const Color(0xFFF4EFFF),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (activity.isLocked)
                          const Icon(Icons.lock_outline, size: 17),
                      ],
                    ),
                    if (activity.location?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 16),
                          const SizedBox(width: 4),
                          Expanded(child: Text(activity.location!)),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('Enjoy ${activity.title} as part of the group itinerary.'),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 13,
                          child: Text(_initials(organizer), style: const TextStyle(fontSize: 10)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Organised by $organizer')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _TimelineAction(
                          icon: Icons.edit_outlined,
                          label: 'Edit',
                          onTap: activity.isLocked && !state.isCreator
                              ? null
                              : () => _showEditActivityDialog(
                                  context,
                                  activity,
                                  viewModel,
                                ),
                        ),
                        _TimelineAction(
                          icon: Icons.share_outlined,
                          label: 'Share',
                          onTap: () => _showActivityShareSheet(
                            context,
                            state,
                            activity,
                            viewModel,
                          ),
                        ),
                        _TimelineAction(
                          icon: activity.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          label: 'Pin',
                          onTap: () => _runWorkspaceAction(
                            context,
                            () => viewModel.togglePin(activity),
                          ),
                        ),
                        _TimelineAction(
                          icon: activity.isLocked
                              ? Icons.lock_open_outlined
                              : Icons.lock_outline,
                          label: activity.isLocked ? 'Unlock' : 'Lock',
                          onTap: state.isCreator
                              ? () => _runWorkspaceAction(
                                  context,
                                  () => viewModel.toggleLock(activity),
                                )
                              : null,
                        ),
                        _TimelineAction(
                          icon: Icons.delete_outline,
                          label: 'Remove',
                          foreground: Colors.red,
                          onTap: !activity.isLocked || state.isCreator
                              ? () => _confirmDeleteActivity(
                                  context,
                                  activity,
                                  viewModel,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteActivity(
  BuildContext context,
  TripActivity activity,
  GroupCollaborationViewModel viewModel,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Remove Activity?'),
      content: Text(
        'Are you sure you want to delete ${activity.title}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Remove'),
        ),
      ],
    ),
  );
  if (confirmed == true && context.mounted) {
    await _runWorkspaceAction(
      context,
      () => viewModel.deleteActivity(activity),
    );
  }
}

Future<void> _showActivityShareSheet(
  BuildContext context,
  GroupCollaborationState state,
  TripActivity activity,
  GroupCollaborationViewModel viewModel,
) async {
  final link =
      'https://gobuddy.app/trips/${state.tripId}/activities/${activity.id}';
  final summary = '${activity.title}\n'
      '${_monthDay(activity.startTime)} at ${_clockTime(activity.startTime)}\n'
      '${activity.location ?? 'Location to be confirmed'}\n$link';
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Wrap(
        children: [
          const ListTile(
            title: Text(
              'Share activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Share to Group Chat'),
            subtitle: const Text('Post an activity preview for trip members.'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await _runWorkspaceAction(
                context,
                () => viewModel.shareActivityToChat(activity),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.ios_share_outlined),
            title: const Text('Share via External Apps'),
            subtitle: const Text('WhatsApp, email, SMS and more.'),
            onTap: () async {
              Navigator.pop(sheetContext);
              await Share.share(summary, subject: activity.title);
            },
          ),
          ListTile(
            leading: const Icon(Icons.link),
            title: const Text('Copy Link'),
            subtitle: const Text('Copy a view-only activity link.'),
            onTap: () async {
              await Clipboard.setData(ClipboardData(text: link));
              if (!sheetContext.mounted) return;
              Navigator.pop(sheetContext);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Activity link copied.')),
                );
              }
            },
          ),
        ],
      ),
    ),
  );
}

class _TimelinePill extends StatelessWidget {
  const _TimelinePill({
    required this.label,
    required this.foreground,
    required this.background,
  });
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _TimelineAction extends StatelessWidget {
  const _TimelineAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.foreground,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? foreground;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          foregroundColor: foreground,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    ),
  );
}

bool _sameDay(DateTime first, DateTime second) =>
    first.year == second.year &&
    first.month == second.month &&
    first.day == second.day;

String _monthDay(DateTime date) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}

String _clockTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  return '$hour:$minute ${date.hour < 12 ? 'AM' : 'PM'}';
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty || parts.first.isEmpty) return '?';
  return parts.take(2).map((part) => part[0].toUpperCase()).join();
}

class _TimelineTab extends ConsumerWidget {
  const _TimelineTab({required this.state});
  final GroupCollaborationState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final viewModel = ref.read(
      groupCollaborationViewModelProvider(state.tripId).notifier,
    );
    final activities = [...state.activities]
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final days = <DateTime>[...state.timelineDays];
    for (final activity in activities) {
      final day = DateTime(
        activity.startTime.year,
        activity.startTime.month,
        activity.startTime.day,
      );
      if (!days.contains(day)) days.add(day);
    }
    days.sort();
    if (days.isEmpty) {
      final now = DateTime.now();
      days.add(DateTime(now.year, now.month, now.day));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Timeline',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        Text('${state.activities.length} planned activities'),
        const SizedBox(height: 16),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Trip days',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Add another day to your itinerary.'),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => _runWorkspaceAction(
                    context,
                    () => viewModel.addTimelineDay(
                      days.last.add(const Duration(days: 1)),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('Day'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 82,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: days.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (_, index) {
              final day = days[index];
              return Container(
                width: 88,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: index == 0
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Text(
                      'Day ${index + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(_weekday(day)),
                    Text(_calendarDate(day)),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ActivityProposalDialog(
                onPropose: (title, location) => viewModel.proposeActivity(
                  title: title,
                  location: location,
                  startTime: days.last.add(const Duration(hours: 12)),
                ),
                onCreatePoll: (question, options) => viewModel
                    .createActivityPoll(question: question, options: options),
              ),
            ),
            icon: const Icon(Icons.add),
            label: const Text('Add Activity'),
          ),
        ),
        const SizedBox(height: 16),
        if (activities.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 48, bottom: 48),
            child: Center(
              child: Text('No activities yet. Tap Add to create one.'),
            ),
          ),
        ...activities.map(
          (activity) => Card(
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: activity.isPinned
                  ? BorderSide(color: Theme.of(context).colorScheme.primary)
                  : BorderSide.none,
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Icon(
                    Icons.circle,
                    size: 14,
                    color: activity.startTime.isBefore(DateTime.now())
                        ? Colors.green
                        : Theme.of(context).colorScheme.primary,
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      _ActivityStatusChip(
                        label: activity.startTime.isBefore(DateTime.now())
                            ? 'In progress'
                            : 'Upcoming',
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${_weekday(activity.startTime)}, ${_calendarDate(activity.startTime)} at ${_shortTime(activity.startTime)}${activity.location?.trim().isNotEmpty == true ? '\n${activity.location}' : ''}\n${state.comments.where((comment) => comment.activityId == activity.id).length} comment(s) · ${_rsvpSummary(state, activity.id)}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    tooltip: 'RSVP',
                    onSelected: (action) {
                      switch (action) {
                        case 'going':
                        case 'maybe':
                        case 'not_going':
                          _runWorkspaceAction(
                            context,
                            () => viewModel.setActivityRsvp(
                              activityId: activity.id,
                              status: action,
                            ),
                          );
                          break;
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'going',
                        child: Text('RSVP: Going'),
                      ),
                      const PopupMenuItem(
                        value: 'maybe',
                        child: Text('RSVP: Maybe'),
                      ),
                      const PopupMenuItem(
                        value: 'not_going',
                        child: Text('RSVP: Not going'),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            _showComments(context, state, activity, viewModel),
                        icon: const Icon(Icons.comment_outlined, size: 16),
                        label: const Text('Comment'),
                      ),
                      OutlinedButton.icon(
                        onPressed: activity.isLocked && !state.isCreator
                            ? null
                            : () => _showEditActivityDialog(
                                context,
                                activity,
                                viewModel,
                              ),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('Edit'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => _runWorkspaceAction(
                          context,
                          () => viewModel.togglePin(activity),
                        ),
                        icon: Icon(
                          activity.isPinned
                              ? Icons.push_pin
                              : Icons.push_pin_outlined,
                          size: 16,
                        ),
                        label: Text(activity.isPinned ? 'Pinned' : 'Pin'),
                      ),
                      if (state.isCreator)
                        OutlinedButton.icon(
                          onPressed: () => _runWorkspaceAction(
                            context,
                            () => viewModel.toggleLock(activity),
                          ),
                          icon: Icon(
                            activity.isLocked
                                ? Icons.lock
                                : Icons.lock_open_outlined,
                            size: 16,
                          ),
                          label: Text(activity.isLocked ? 'Unlock' : 'Lock'),
                        ),
                    ],
                  ),
                ),
              ],
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

class _ActivityStatusChip extends StatelessWidget {
  const _ActivityStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
    ),
  );
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

String _calendarDate(DateTime value) => '${value.day}/${value.month}';

String _weekday(DateTime value) => const [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
][value.weekday - 1];

String _shortTime(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

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
