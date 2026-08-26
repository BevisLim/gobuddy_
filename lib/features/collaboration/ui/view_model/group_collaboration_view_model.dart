import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/repository/collaboration_repository.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model.dart';

final groupCollaborationViewModelProvider =
    AsyncNotifierProvider.family<
      GroupCollaborationViewModel,
      GroupCollaborationState,
      String
    >(GroupCollaborationViewModel.new);

class GroupCollaborationViewModel
    extends AsyncNotifier<GroupCollaborationState> {
  GroupCollaborationViewModel(this._tripId);

  final String _tripId;
  late CollaborationRepository _repository;
  RealtimeChannel? _channel;

  @override
  Future<GroupCollaborationState> build() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Please sign in before opening a trip workspace.');
    }
    _repository = ref.read(collaborationRepositoryProvider);
    final workspace = await _repository
        .loadWorkspace(tripId: _tripId, currentUserId: userId)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'The trip workspace took too long to load. Check your Supabase connection and trip membership.',
          ),
        );
    final channel = _repository.subscribe(
      _tripId,
      () => ref.invalidateSelf(),
    );
    _channel = channel;
    ref.onDispose(() {
      supabase.removeChannel(channel);
      if (identical(_channel, channel)) _channel = null;
    });
    return workspace;
  }

  GroupCollaborationState? get _current {
    final currentState = state;
    return switch (currentState) {
      AsyncData<GroupCollaborationState>(:final value) => value,
      _ => null,
    };
  }

  Future<void> sendMessage(String body) async {
    final current = _current;
    if (current == null || body.trim().isEmpty) {
      return;
    }
    final activeUserId = supabase.auth.currentUser?.id;
    if (activeUserId == null) {
      throw StateError('Please sign in before sending a message.');
    }
    if (activeUserId != current.currentUserId) {
      // Never send with identity cached from a previous account. Rebuilding
      // also fixes which messages are labelled as "You".
      ref.invalidateSelf();
      throw StateError(
        'Your account changed. The group was refreshed; please send again.',
      );
    }
    if (current.isMuted) {
      throw StateError(
        'You are muted until the trip creator enables chat again.',
      );
    }
    await _repository.sendMessage(current.tripId, activeUserId, body.trim());
    await _repository.setTyping(
      tripId: current.tripId,
      userId: activeUserId,
      isTyping: false,
    );
    // Show the sender's message immediately after a successful insert.
    // Realtime remains useful for other members; the sender does not need a reply.
    ref.invalidateSelf();
  }

  Future<void> muteMember(String memberId, Duration duration) async {
    final current = _requireMemberManager();
    await _repository.setMutedUntil(
      tripId: current.tripId,
      memberId: memberId,
      mutedUntil: DateTime.now().add(duration),
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'member_muted',
      summary:
          '${_memberName(current, current.currentUserId)} muted ${_memberName(current, memberId)}.',
    );
    ref.invalidateSelf();
  }

  Future<void> unmuteMember(String memberId) async {
    final current = _requireMemberManager();
    await _repository.setMutedUntil(
      tripId: current.tripId,
      memberId: memberId,
      mutedUntil: null,
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'member_unmuted',
      summary:
          '${_memberName(current, current.currentUserId)} unmuted ${_memberName(current, memberId)}.',
    );
    ref.invalidateSelf();
  }

  Future<void> removeMember(String memberId) async {
    final current = _requireMemberManager();
    if (memberId == current.creatorId) {
      throw StateError('The trip creator cannot be removed.');
    }
    await _repository.removeMember(current.tripId, memberId);
    // Update the owner's traveller count immediately. Other sessions receive
    // the same membership deletion through Supabase Realtime.
    unawaited(ref.read(matchmakingViewModelProvider.notifier).refresh());
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'member_removed',
      summary:
          '${_memberName(current, current.currentUserId)} removed ${_memberName(current, memberId)} from the group.',
    );
    ref.invalidateSelf();
  }

  Future<void> makeAdmin(String memberId) async {
    final current = _requireCreator();
    if (memberId == current.creatorId) {
      throw StateError('The trip creator already has admin permissions.');
    }
    await _repository.makeAdmin(tripId: current.tripId, memberId: memberId);
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'admin_assigned',
      summary:
          '${_memberName(current, current.currentUserId)} made ${_memberName(current, memberId)} an admin.',
    );
    ref.invalidateSelf();
  }

  Future<void> removeAdmin(String memberId) async {
    final current = _requireCreator();
    await _repository.removeAdmin(tripId: current.tripId, memberId: memberId);
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'admin_removed',
      summary:
          '${_memberName(current, current.currentUserId)} removed admin access from ${_memberName(current, memberId)}.',
    );
    ref.invalidateSelf();
  }

  Future<void> proposeActivity({
    required String title,
    required DateTime startTime,
    String? location,
  }) async {
    final current = _current;
    if (current == null) return;
    await _repository.addActivity(
      tripId: current.tripId,
      title: title,
      startTime: startTime,
      location: location,
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'activity_created',
      summary: 'A new activity was proposed: ${title.trim()}.',
    );
    ref.invalidateSelf();
  }

  Future<void> addTimelineDay(DateTime day) async {
    final current = _current;
    if (current == null) return;
    await _repository.addTimelineDay(current.tripId, day);
    ref.invalidateSelf();
  }

  Future<void> togglePin(TripActivity activity) async {
    final current = _current;
    if (current == null) return;
    await _repository.updateActivity(activity.id, {
      'is_pinned': !activity.isPinned,
    });
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'activity_pinned',
      summary:
          '${activity.title} was ${activity.isPinned ? 'unpinned' : 'pinned'}.',
    );
    ref.invalidateSelf();
  }

  Future<void> toggleLock(TripActivity activity) async {
    _requireCreator();
    await _repository.updateActivity(activity.id, {
      'is_locked': !activity.isLocked,
    });
    ref.invalidateSelf();
  }

  Future<void> createActivityPoll({
    required String question,
    required List<String> options,
  }) async {
    final current = _current;
    final cleanedOptions = options
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toList();
    if (current == null ||
        question.trim().isEmpty ||
        cleanedOptions.length < 2) {
      throw StateError('Enter a question and at least two poll options.');
    }
    await _repository.createPoll(
      tripId: current.tripId,
      question: question.trim(),
      options: cleanedOptions,
    );
    ref.invalidateSelf();
  }

  Future<void> editActivity({
    required TripActivity activity,
    required String title,
    required DateTime startTime,
    String? location,
  }) async {
    final current = _current;
    if (current == null) return;
    if (activity.isLocked && !current.isCreator) {
      throw StateError('This itinerary item is locked by the trip creator.');
    }
    await _repository.updateActivity(activity.id, {
      'title': title,
      'start_time': startTime.toUtc().toIso8601String(),
      'location': location,
    });
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'activity_edited',
      summary: 'Activity updated: ${title.trim()}.',
    );
    ref.invalidateSelf();
  }

  Future<void> deleteActivity(TripActivity activity) async {
    final current = _current;
    if (current == null) return;
    if (activity.isLocked && !current.isCreator) {
      throw StateError('Only the trip creator can remove a locked activity.');
    }
    await _repository.deleteActivity(activity.id);
    await _repository.sendMessage(
      current.tripId,
      current.currentUserId,
      '[system]Activity removed: ${activity.title}',
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'activity_removed',
      summary: 'Activity removed: ${activity.title}.',
    );
    ref.invalidateSelf();
  }

  Future<void> shareActivityToChat(TripActivity activity) async {
    final current = _current;
    if (current == null) return;
    final location = activity.location?.trim();
    await _repository.sendMessage(
      current.tripId,
      current.currentUserId,
      '[activity_share]${activity.id}|${activity.title}|${activity.startTime.toIso8601String()}|${location ?? ''}',
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'activity_shared',
      summary: 'Shared ${activity.title} to the group chat.',
    );
    ref.invalidateSelf();
  }

  Future<void> castVote(String pollId, String optionId) async {
    final current = _current;
    if (current == null) return;
    await _repository.castVote(pollId: pollId, optionId: optionId);
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'vote_cast',
      summary: 'A member voted in an activity poll.',
    );
    ref.invalidateSelf();
  }

  Future<void> setActivityRsvp({
    required String activityId,
    required String status,
  }) async {
    final current = _current;
    if (current == null) return;
    await _repository.setActivityRsvp(
      tripId: current.tripId,
      activityId: activityId,
      userId: current.currentUserId,
      status: status,
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'rsvp_updated',
      summary:
          '${_memberName(current, current.currentUserId)} responded "$status" to an activity.',
    );
    ref.invalidateSelf();
  }

  Future<void> setTyping(bool isTyping) async {
    final current = _current;
    if (current == null) return;
    await _repository.setTyping(
      tripId: current.tripId,
      userId: current.currentUserId,
      isTyping: isTyping,
    );
  }

  Future<void> markMessagesRead() async {
    final current = _current;
    if (current == null) return;
    await _repository.markMessagesRead(current.tripId);
  }

  Future<void> markCollaborationNotificationsRead() async {
    final current = _current;
    if (current == null || current.unreadNotifications.isEmpty) return;
    await _repository.markCollaborationNotificationsRead(current.tripId);
    ref.invalidateSelf();
  }

  Future<void> pickAndShareFile() async {
    final current = _current;
    if (current == null) return;
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file = picked == null || picked.files.isEmpty
        ? null
        : picked.files.first;
    if (file == null || file.bytes == null) return;
    await _repository.uploadFile(
      tripId: current.tripId,
      userId: current.currentUserId,
      fileName: file.name,
      bytes: file.bytes!,
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'file_shared',
      summary: 'A file was shared with the group: ${file.name}.',
    );
    ref.invalidateSelf();
  }

  Future<void> takeAndSharePhoto() async {
    final current = _current;
    if (current == null) return;
    if (current.isMuted) {
      throw StateError(
        'You are muted until the trip creator enables chat again.',
      );
    }
    final image = await ImagePicker().pickImage(
      source: ImageSource.camera,
      imageQuality: 82,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    final url = await _repository.uploadFile(
      tripId: current.tripId,
      userId: current.currentUserId,
      fileName: image.name.isEmpty ? 'photo.jpg' : image.name,
      bytes: bytes,
    );
    await _repository.sendMessage(
      current.tripId,
      current.currentUserId,
      '[photo]$url',
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'file_shared',
      summary: 'A photo was shared with the group.',
    );
    ref.invalidateSelf();
  }

  Future<void> shareVoiceMessage(Uint8List bytes) async {
    final current = _current;
    if (current == null || bytes.isEmpty) return;
    if (current.isMuted) {
      throw StateError(
        'You are muted until the trip creator enables chat again.',
      );
    }
    final url = await _repository.uploadFile(
      tripId: current.tripId,
      userId: current.currentUserId,
      fileName: 'voice_${DateTime.now().millisecondsSinceEpoch}.webm',
      bytes: bytes,
    );
    await _repository.sendMessage(
      current.tripId,
      current.currentUserId,
      '[voice]$url',
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'file_shared',
      summary: 'A voice message was shared with the group.',
    );
    ref.invalidateSelf();
  }

  Future<TripCall?> startCall(String type) async {
    final current = _current;
    if (current == null) return null;
    final call = await _repository.startCall(
      tripId: current.tripId,
      type: type,
    );
    await _repository.updateCallStatus(callId: call.id, status: 'active');
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'call_started',
      summary: 'A ${type.trim()} call was started.',
    );
    ref.invalidateSelf();
    return call;
  }

  Future<TripCall?> joinCall(TripCall call) async {
    final current = _current;
    if (current == null || call.status == 'ended') return null;
    if (call.status == 'ringing') {
      await _repository.updateCallStatus(callId: call.id, status: 'active');
    }
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'call_joined',
      summary: 'A member joined a ${call.callType} call.',
    );
    ref.invalidateSelf();
    return call;
  }

  Future<void> endCall(TripCall call) async {
    final current = _current;
    if (current == null ||
        (call.initiatedBy != current.currentUserId &&
            !current.canManageMembers)) {
      throw StateError('Only the call starter or an admin can end this call.');
    }
    await _repository.updateCallStatus(callId: call.id, status: 'ended');
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'call_ended',
      summary:
          '${_memberName(current, current.currentUserId)} ended a ${call.callType} call.',
    );
    ref.invalidateSelf();
  }

  Future<void> deleteFile(SharedTripFile file) async {
    final current = _current;
    if (current == null ||
        (file.uploadedBy != current.currentUserId &&
            !current.canManageMembers)) {
      throw StateError('Only the uploader or an admin can delete this file.');
    }
    await _repository.deleteFile(file);
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'file_deleted',
      summary:
          '${_memberName(current, current.currentUserId)} removed ${file.name}.',
    );
    ref.invalidateSelf();
  }

  Future<void> addActivityComment({
    required String activityId,
    required String body,
  }) async {
    final current = _current;
    if (current == null || body.trim().isEmpty) return;
    await _repository.addActivityComment(
      tripId: current.tripId,
      activityId: activityId,
      authorId: current.currentUserId,
      body: body.trim(),
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'comment_added',
      summary: 'A new activity comment was added.',
    );
    ref.invalidateSelf();
  }

  GroupCollaborationState _requireMemberManager() {
    final current = _current;
    if (current == null || !current.canManageMembers) {
      throw StateError(
        'Only the trip creator or an admin can perform this action.',
      );
    }
    return current;
  }

  GroupCollaborationState _requireCreator() {
    final current = _current;
    if (current == null || !current.isCreator) {
      throw StateError('Only the trip creator can lock an activity.');
    }
    return current;
  }

  String _memberName(GroupCollaborationState state, String userId) {
    if (userId == state.currentUserId) return 'You';
    return state.members
            .where((member) => member.userId == userId)
            .map((member) => member.displayName)
            .whereType<String>()
            .firstOrNull ??
        'A member';
  }
}
