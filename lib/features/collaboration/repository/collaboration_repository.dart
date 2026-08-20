import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';

final collaborationRepositoryProvider = Provider<CollaborationRepository>(
    (ref) => CollaborationRepository(supabase));

class CollaborationRepository {
  CollaborationRepository(this._client);

  final SupabaseClient _client;

  Future<GroupCollaborationState> loadWorkspace({
    required String tripId,
    required String currentUserId,
  }) async {
    final trip = await _client
        .from('matchmaking_trips')
        .select('owner_id')
        .eq('id', tripId)
        .single();
    final results = await Future.wait<dynamic>([
      _client
          .from('matchmaking_trip_members')
          .select('user_id, muted_until')
          .eq('trip_id', tripId),
      _client
          .from('trip_messages')
          .select()
          .eq('trip_id', tripId)
          .order('sent_at'),
      _client
          .from('trip_activities')
          .select()
          .eq('trip_id', tripId)
          .order('is_pinned', ascending: false)
          .order('start_time'),
      _client
          .from('trip_files')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false),
      _client.from('trip_polls').select('id, question').eq('trip_id', tripId),
    ]);
    final polls = <ActivityPoll>[];
    for (final rawPoll in results[4] as List<dynamic>) {
      final poll = rawPoll as Map<String, dynamic>;
      final options = await _client
          .from('trip_poll_options')
          .select('id, label, trip_poll_votes(user_id)')
          .eq('poll_id', poll['id'])
          .order('created_at');
      polls.add(ActivityPoll(
        id: poll['id'] as String,
        question: poll['question'] as String,
        options: (options as List<dynamic>).map((rawOption) {
          final option = rawOption as Map<String, dynamic>;
          final votes = option['trip_poll_votes'] as List<dynamic>? ?? const [];
          return PollOption(
            id: option['id'] as String,
            label: option['label'] as String,
            voterIds: votes
                .map((vote) =>
                    (vote as Map<String, dynamic>)['user_id'] as String)
                .toList(),
          );
        }).toList(),
      ));
    }
    return GroupCollaborationState(
      tripId: tripId,
      currentUserId: currentUserId,
      creatorId: trip['owner_id'] as String,
      members: (results[0] as List<dynamic>)
          .map((member) =>
              CollaborationMember.fromMap(member as Map<String, dynamic>))
          .toList(),
      messages: (results[1] as List<dynamic>)
          .map(
              (message) => TripMessage.fromMap(message as Map<String, dynamic>))
          .toList(),
      activities: (results[2] as List<dynamic>)
          .map((activity) =>
              TripActivity.fromMap(activity as Map<String, dynamic>))
          .toList(),
      polls: polls,
      files: (results[3] as List<dynamic>)
          .map((file) => SharedTripFile.fromMap(file as Map<String, dynamic>))
          .toList(),
    );
  }

  RealtimeChannel subscribe(String tripId, void Function() onChange) {
    return _client.channel('trip-workspace-$tripId')
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_messages',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_activities',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId),
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_files',
        filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'trip_id',
            value: tripId),
        callback: (_) => onChange(),
      )
      ..subscribe();
  }

  Future<void> sendMessage(String tripId, String userId, String body) => _client
      .from('trip_messages')
      .insert({'trip_id': tripId, 'sender_id': userId, 'body': body});

  Future<void> setMute(
          {required String tripId,
          required String memberId,
          required Duration duration}) =>
      _client
          .from('matchmaking_trip_members')
          .update({
            'muted_until':
                DateTime.now().add(duration).toUtc().toIso8601String(),
          })
          .eq('trip_id', tripId)
          .eq('user_id', memberId);

  Future<void> removeMember(String tripId, String memberId) => _client
      .from('matchmaking_trip_members')
      .delete()
      .eq('trip_id', tripId)
      .eq('user_id', memberId);

  Future<void> addActivity(
          {required String tripId,
          required String title,
          required DateTime startTime,
          String? location}) =>
      _client.from('trip_activities').insert({
        'trip_id': tripId,
        'title': title,
        'start_time': startTime.toUtc().toIso8601String(),
        'location': location,
      });

  Future<void> updateActivity(String activityId, Map<String, dynamic> values) =>
      _client.from('trip_activities').update(values).eq('id', activityId);

  Future<void> createPoll({
    required String tripId,
    required String question,
    required List<String> options,
  }) async {
    final poll = await _client
        .from('trip_polls')
        .insert({'trip_id': tripId, 'question': question})
        .select('id')
        .single();
    final pollId = poll['id'] as String;
    await _client.from('trip_poll_options').insert([
      for (final option in options) {'poll_id': pollId, 'label': option},
    ]);
  }

  Future<void> castVote({required String pollId, required String optionId}) =>
      _client.rpc('cast_trip_poll_vote',
          params: {'p_poll_id': pollId, 'p_option_id': optionId});

  Future<void> uploadFile({
    required String tripId,
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final storagePath =
        '$tripId/${DateTime.now().microsecondsSinceEpoch}_$fileName';
    await _client.storage
        .from('trip-documents')
        .uploadBinary(storagePath, bytes);
    final url =
        _client.storage.from('trip-documents').getPublicUrl(storagePath);
    await _client.from('trip_files').insert({
      'trip_id': tripId,
      'file_name': fileName,
      'file_url': url,
      'storage_path': storagePath,
      'uploaded_by': userId,
    });
  }

  Future<void> startCall({required String tripId, required String type}) =>
      _client
          .from('trip_calls')
          .insert({'trip_id': tripId, 'call_type': type, 'status': 'ringing'});
}
