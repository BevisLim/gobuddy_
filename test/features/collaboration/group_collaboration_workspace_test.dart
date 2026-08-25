import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_mvvm_riverpod/features/collaboration/model/collaboration_models.dart';

void main() {
  GroupCollaborationState workspace({
    String currentUserId = 'owner',
    String creatorId = 'owner',
    bool isAdmin = false,
  }) => GroupCollaborationState(
    tripId: 'trip-1',
    currentUserId: currentUserId,
    creatorId: creatorId,
    isAdmin: isAdmin,
    members: const [],
    messages: const [],
    activities: const [],
    polls: const [],
    files: const [],
    comments: const [],
    notifications: const [],
    calls: const [],
  );

  test('only the creator or an admin can manage members', () {
    expect(workspace().canManageMembers, isTrue);
    expect(
      workspace(
        currentUserId: 'admin',
        creatorId: 'owner',
        isAdmin: true,
      ).canManageMembers,
      isTrue,
    );
    expect(
      workspace(currentUserId: 'member', creatorId: 'owner').canManageMembers,
      isFalse,
    );
  });

  test('real workspace member roles and mute state are represented', () {
    final member = CollaborationMember(
      userId: 'member',
      displayName: 'Aina',
      isAdmin: true,
      mutedUntil: DateTime.now().add(const Duration(minutes: 30)),
    );

    expect(member.displayName, 'Aina');
    expect(member.isAdmin, isTrue);
    expect(member.isMuted, isTrue);
  });

  test('maps a Supabase call-history row for the shared Jitsi room', () {
    final call = TripCall.fromMap({
      'id': 'call-1',
      'initiated_by': 'owner',
      'call_type': 'video',
      'status': 'ringing',
      'created_at': '2026-08-25T12:00:00.000Z',
    }, initiatedByName: 'Thai Hong');

    expect(call.isVideo, isTrue);
    expect(call.initiatedByName, 'Thai Hong');
    expect(call.status, 'ringing');
  });

  test('maps a live collaboration event from Supabase', () {
    final event = CollaborationNotification.fromMap({
      'id': 'event-1',
      'actor_id': 'member',
      'event_type': 'file_shared',
      'summary': 'A file was shared with the group: booking.pdf.',
      'created_at': '2026-08-25T12:00:00.000Z',
    });

    expect(event.eventType, 'file_shared');
    expect(event.summary, contains('booking.pdf'));
  });
}
