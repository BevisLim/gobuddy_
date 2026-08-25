import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/repository/collaboration_repository.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/repository/jitsi_call_repository.dart';

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
  final JitsiCallRepository _callRepository = const JitsiCallRepository();
  RealtimeChannel? _channel;

  @override
  Future<GroupCollaborationState> build() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Please sign in before opening a trip workspace.');
    }
    _repository = ref.read(collaborationRepositoryProvider);
    _channel ??= _repository.subscribe(_tripId, () => ref.invalidateSelf());
    ref.onDispose(() {
      if (_channel != null) supabase.removeChannel(_channel!);
    });
    return _repository
        .loadWorkspace(tripId: _tripId, currentUserId: userId)
        .timeout(
          const Duration(seconds: 15),
          onTimeout: () => throw TimeoutException(
            'The trip workspace took too long to load. Check your Supabase connection and trip membership.',
          ),
        );
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
    if (current.isMuted) {
      throw StateError(
        'You are muted until the trip creator enables chat again.',
      );
    }
    await _repository.sendMessage(
      current.tripId,
      current.currentUserId,
      body.trim(),
    );
  }

  Future<void> muteMember(String memberId, Duration duration) async {
    final current = _requireMemberManager();
    await _repository.setMute(
      tripId: current.tripId,
      memberId: memberId,
      duration: duration,
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'member_muted',
      summary: 'A group member was muted.',
    );
    ref.invalidateSelf();
  }

  Future<void> removeMember(String memberId) async {
    final current = _requireMemberManager();
    if (memberId == current.creatorId) {
      throw StateError('The trip creator cannot be removed.');
    }
    await _repository.removeMember(current.tripId, memberId);
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'member_removed',
      summary: 'A group member was removed.',
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
      summary: 'A group member was made an admin.',
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

  Future<void> startCall(String type) async {
    final current = _current;
    if (current == null) return;
    await _repository.startCall(tripId: current.tripId, type: type);
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'call_started',
      summary: 'A ${type.trim()} call was started.',
    );
    await _callRepository.joinTripCall(tripId: current.tripId, callType: type);
  }

  Future<void> joinCall(TripCall call) async {
    final current = _current;
    if (current == null) return;
    await _callRepository.joinTripCall(
      tripId: current.tripId,
      callType: call.callType,
    );
    await _repository.recordEvent(
      tripId: current.tripId,
      actorId: current.currentUserId,
      type: 'call_joined',
      summary: 'A member joined a ${call.callType} call.',
    );
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
}
