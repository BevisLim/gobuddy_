import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/repository/collaboration_repository.dart';

final groupCollaborationViewModelProvider = AsyncNotifierProvider.family<
    GroupCollaborationViewModel, GroupCollaborationState, String>(
  GroupCollaborationViewModel.new,
);

class GroupCollaborationViewModel
    extends AsyncNotifier<GroupCollaborationState> {
  GroupCollaborationViewModel(this._tripId);

  final String _tripId;
  late CollaborationRepository _repository;
  RealtimeChannel? _channel;

  @override
  Future<GroupCollaborationState> build() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null)
      throw StateError('Please sign in before opening a trip workspace.');
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
            'The trip workspace took too long to load. Check your connection and Supabase migration.',
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
    if (current == null || body.trim().isEmpty) return;
    if (current.isMuted)
      throw StateError(
          'You are muted until the trip creator enables chat again.');
    await _repository.sendMessage(
        current.tripId, current.currentUserId, body.trim());
  }

  Future<void> muteMember(String memberId, Duration duration) async {
    final current = _requireCreator();
    await _repository.setMute(
        tripId: current.tripId, memberId: memberId, duration: duration);
    ref.invalidateSelf();
  }

  Future<void> removeMember(String memberId) async {
    final current = _requireCreator();
    if (memberId == current.creatorId)
      throw StateError('The trip creator cannot be removed.');
    await _repository.removeMember(current.tripId, memberId);
    ref.invalidateSelf();
  }

  Future<void> proposeActivity(
      {required String title,
      required DateTime startTime,
      String? location}) async {
    final current = _current;
    if (current == null) return;
    await _repository.addActivity(
      tripId: current.tripId,
      title: title,
      startTime: startTime,
      location: location,
    );
    ref.invalidateSelf();
  }

  Future<void> togglePin(TripActivity activity) async {
    if (_current == null) return;
    await _repository
        .updateActivity(activity.id, {'is_pinned': !activity.isPinned});
    ref.invalidateSelf();
  }

  Future<void> toggleLock(TripActivity activity) async {
    _requireCreator();
    await _repository
        .updateActivity(activity.id, {'is_locked': !activity.isLocked});
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
    ref.invalidateSelf();
  }

  Future<void> castVote(String pollId, String optionId) async {
    if (_current == null) return;
    await _repository.castVote(pollId: pollId, optionId: optionId);
    ref.invalidateSelf();
  }

  Future<void> pickAndShareFile() async {
    final current = _current;
    if (current == null) return;
    final picked = await FilePicker.platform.pickFiles(withData: true);
    final file =
        picked == null || picked.files.isEmpty ? null : picked.files.first;
    if (file == null || file.bytes == null) return;
    await _repository.uploadFile(
      tripId: current.tripId,
      userId: current.currentUserId,
      fileName: file.name,
      bytes: file.bytes!,
    );
    ref.invalidateSelf();
  }

  Future<void> startCall(String type) async {
    final current = _current;
    if (current == null) return;
    await _repository.startCall(tripId: current.tripId, type: type);
  }

  GroupCollaborationState _requireCreator() {
    final current = _current;
    if (current == null || !current.isCreator) {
      throw StateError('Only the trip creator can perform this action.');
    }
    return current;
  }
}
