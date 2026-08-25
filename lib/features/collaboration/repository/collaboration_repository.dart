import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:flutter_mvvm_riverpod/features/common/remote/supabase_client.dart';
import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';

final collaborationRepositoryProvider = Provider<CollaborationRepository>(
  (ref) => CollaborationRepository(supabase),
);

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
          .from('trip_members')
          .select('user_id, muted_until')
          .eq('trip_id', tripId),
      _client
          .from('trip_messages')
          .select('*, trip_message_reads(user_id)')
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
      _client
          .from('trip_member_roles')
          .select('user_id, role')
          .eq('trip_id', tripId),
      _client
          .from('trip_activity_comments')
          .select()
          .eq('trip_id', tripId)
          .order('created_at'),
      _client
          .from('trip_activity_events')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false)
          .limit(20),
      _client.from('user_accounts').select('id, display_name'),
      _client
          .from('trip_calls')
          .select()
          .eq('trip_id', tripId)
          .order('created_at', ascending: false)
          .limit(20),
      _client
          .from('trip_activity_rsvps')
          .select('activity_id, user_id, status')
          .eq('trip_id', tripId),
      _client
          .from('trip_typing_status')
          .select('user_id')
          .eq('trip_id', tripId)
          .gt(
            'updated_at',
            DateTime.now()
                .subtract(const Duration(seconds: 12))
                .toUtc()
                .toIso8601String(),
          ),
    ]);
    final profileNames = <String, String>{
      for (final profile in results[8] as List<dynamic>)
        (profile as Map<String, dynamic>)['id'] as String:
            profile['display_name'] as String,
    };
    final adminIds = (results[5] as List<dynamic>)
        .where((role) => (role as Map<String, dynamic>)['role'] == 'admin')
        .map((role) => (role as Map<String, dynamic>)['user_id'] as String)
        .toSet();
    final polls = <ActivityPoll>[];
    for (final rawPoll in results[4] as List<dynamic>) {
      final poll = rawPoll as Map<String, dynamic>;
      final options = await _client
          .from('trip_poll_options')
          .select('id, label, trip_poll_votes(user_id)')
          .eq('poll_id', poll['id'])
          .order('created_at');
      polls.add(
        ActivityPoll(
          id: poll['id'] as String,
          question: poll['question'] as String,
          options: (options as List<dynamic>).map((rawOption) {
            final option = rawOption as Map<String, dynamic>;
            final votes =
                option['trip_poll_votes'] as List<dynamic>? ?? const [];
            return PollOption(
              id: option['id'] as String,
              label: option['label'] as String,
              voterIds: votes
                  .map(
                    (vote) =>
                        (vote as Map<String, dynamic>)['user_id'] as String,
                  )
                  .toList(),
            );
          }).toList(),
        ),
      );
    }
    return GroupCollaborationState(
      tripId: tripId,
      currentUserId: currentUserId,
      creatorId: trip['owner_id'] as String,
      isAdmin: adminIds.contains(currentUserId),
      members: (results[0] as List<dynamic>).map((member) {
        final row = member as Map<String, dynamic>;
        return CollaborationMember.fromMap(
          row,
          displayName: profileNames[row['user_id'] as String],
          isAdmin: adminIds.contains(row['user_id'] as String),
        );
      }).toList(),
      messages: (results[1] as List<dynamic>).map((message) {
        final row = message as Map<String, dynamic>;
        return TripMessage.fromMap(
          row,
          senderName: profileNames[row['sender_id'] as String],
          readByCount:
              (row['trip_message_reads'] as List<dynamic>? ?? const []).length,
        );
      }).toList(),
      activities: (results[2] as List<dynamic>)
          .map(
            (activity) =>
                TripActivity.fromMap(activity as Map<String, dynamic>),
          )
          .toList(),
      polls: polls,
      files: (results[3] as List<dynamic>).map((file) {
        final row = file as Map<String, dynamic>;
        return SharedTripFile.fromMap(
          row,
          uploadedByName: profileNames[row['uploaded_by'] as String],
        );
      }).toList(),
      comments: (results[6] as List<dynamic>)
          .map(
            (comment) =>
                ActivityComment.fromMap(comment as Map<String, dynamic>),
          )
          .toList(),
      notifications: (results[7] as List<dynamic>)
          .map(
            (event) => CollaborationNotification.fromMap(
              event as Map<String, dynamic>,
            ),
          )
          .toList(),
      calls: (results[9] as List<dynamic>).map((call) {
        final row = call as Map<String, dynamic>;
        return TripCall.fromMap(
          row,
          initiatedByName: profileNames[row['initiated_by'] as String],
        );
      }).toList(),
      rsvps: (results[10] as List<dynamic>)
          .map((rsvp) => ActivityRsvp.fromMap(rsvp as Map<String, dynamic>))
          .toList(),
      typingMemberNames: (results[11] as List<dynamic>)
          .map(
            (typing) => (typing as Map<String, dynamic>)['user_id'] as String,
          )
          .where((userId) => userId != currentUserId)
          .map((userId) => profileNames[userId] ?? 'A trip member')
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
        table: 'trip_polls',
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
        table: 'trip_poll_votes',
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_activity_comments',
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
        table: 'trip_activity_events',
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
          value: tripId,
        ),
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_files',
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
        table: 'trip_calls',
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
        table: 'trip_typing_status',
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
        table: 'trip_message_reads',
        callback: (_) => onChange(),
      )
      ..onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'trip_activity_rsvps',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'trip_id',
          value: tripId,
        ),
        callback: (_) => onChange(),
      )
      ..subscribe();
  }

  Future<void> sendMessage(String tripId, String userId, String body) => _client
      .from('trip_messages')
      .insert({'trip_id': tripId, 'sender_id': userId, 'body': body});

  Future<void> setMutedUntil({
    required String tripId,
    required String memberId,
    required DateTime? mutedUntil,
  }) => _client
      .from('trip_members')
      .update({
        'muted_until': mutedUntil?.toUtc().toIso8601String(),
      })
      .eq('trip_id', tripId)
      .eq('user_id', memberId);

  Future<void> unmuteMember({
    required String tripId,
    required String memberId,
  }) => _client
      .from('trip_members')
      .update({'muted_until': null})
      .eq('trip_id', tripId)
      .eq('user_id', memberId);

  Future<void> removeMember(String tripId, String memberId) => _client
      .from('trip_members')
      .delete()
      .eq('trip_id', tripId)
      .eq('user_id', memberId);

  Future<void> makeAdmin({required String tripId, required String memberId}) =>
      _client.from('trip_member_roles').upsert({
        'trip_id': tripId,
        'user_id': memberId,
        'role': 'admin',
      }, onConflict: 'trip_id,user_id,role');

  Future<void> removeAdmin({
    required String tripId,
    required String memberId,
  }) => _client
      .from('trip_member_roles')
      .delete()
      .eq('trip_id', tripId)
      .eq('user_id', memberId)
      .eq('role', 'admin');

  Future<void> addActivity({
    required String tripId,
    required String title,
    required DateTime startTime,
    String? location,
  }) => _client.from('trip_activities').insert({
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
      _client.rpc(
        'cast_trip_poll_vote',
        params: {'p_poll_id': pollId, 'p_option_id': optionId},
      );

  Future<String> uploadFile({
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
    final url = _client.storage
        .from('trip-documents')
        .getPublicUrl(storagePath);
    await _client.from('trip_files').insert({
      'trip_id': tripId,
      'file_name': fileName,
      'file_url': url,
      'storage_path': storagePath,
      'uploaded_by': userId,
      'file_size_bytes': bytes.length,
    });
    return url;
  }

  Future<void> deleteFile(SharedTripFile file) async {
    await _client.storage.from('trip-documents').remove([file.storagePath]);
    await _client.from('trip_files').delete().eq('id', file.id);
  }

  Future<TripCall> startCall({
    required String tripId,
    required String type,
  }) async {
    final call = await _client
        .from('trip_calls')
        .insert({'trip_id': tripId, 'call_type': type, 'status': 'ringing'})
        .select()
        .single();
    return TripCall.fromMap(call);
  }

  Future<void> updateCallStatus({
    required String callId,
    required String status,
  }) => _client.from('trip_calls').update({'status': status}).eq('id', callId);

  Future<void> setActivityRsvp({
    required String tripId,
    required String activityId,
    required String userId,
    required String status,
  }) => _client.from('trip_activity_rsvps').upsert({
    'trip_id': tripId,
    'activity_id': activityId,
    'user_id': userId,
    'status': status,
  }, onConflict: 'activity_id,user_id');

  Future<void> setTyping({
    required String tripId,
    required String userId,
    required bool isTyping,
  }) async {
    final query = _client.from('trip_typing_status');
    if (isTyping) {
      await query.upsert({
        'trip_id': tripId,
        'user_id': userId,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'trip_id,user_id');
    } else {
      await query.delete().eq('trip_id', tripId).eq('user_id', userId);
    }
  }

  Future<void> markMessagesRead(String tripId) =>
      _client.rpc('mark_trip_messages_read', params: {'p_trip_id': tripId});

  Future<void> addActivityComment({
    required String tripId,
    required String activityId,
    required String authorId,
    required String body,
  }) => _client.from('trip_activity_comments').insert({
    'trip_id': tripId,
    'activity_id': activityId,
    'author_id': authorId,
    'body': body,
  });

  Future<void> recordEvent({
    required String tripId,
    required String actorId,
    required String type,
    required String summary,
  }) => _client.from('trip_activity_events').insert({
    'trip_id': tripId,
    'actor_id': actorId,
    'event_type': type,
    'summary': summary,
  });
}
