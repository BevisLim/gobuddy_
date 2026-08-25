class CollaborationMember {
  const CollaborationMember({
    required this.userId,
    this.displayName,
    this.mutedUntil,
  });

  final String userId;
  final String? displayName;
  final DateTime? mutedUntil;

  bool get isMuted => mutedUntil?.isAfter(DateTime.now()) ?? false;

  factory CollaborationMember.fromMap(
    Map<String, dynamic> map, {
    String? displayName,
  }) => CollaborationMember(
    userId: map['user_id'] as String,
    displayName: displayName,
    mutedUntil: map['muted_until'] == null
        ? null
        : DateTime.parse(map['muted_until'] as String).toLocal(),
  );
}

class TripMessage {
  const TripMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
    this.senderName,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime sentAt;
  final String? senderName;

  factory TripMessage.fromMap(Map<String, dynamic> map, {String? senderName}) =>
      TripMessage(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        body: map['body'] as String,
        sentAt: DateTime.parse(map['sent_at'] as String).toLocal(),
        senderName: senderName,
      );
}

class TripActivity {
  const TripActivity({
    required this.id,
    required this.title,
    required this.startTime,
    required this.location,
    required this.isPinned,
    required this.isLocked,
  });

  final String id;
  final String title;
  final DateTime startTime;
  final String? location;
  final bool isPinned;
  final bool isLocked;

  factory TripActivity.fromMap(Map<String, dynamic> map) => TripActivity(
    id: map['id'] as String,
    title: map['title'] as String,
    startTime: DateTime.parse(map['start_time'] as String).toLocal(),
    location: map['location'] as String?,
    isPinned: map['is_pinned'] as bool? ?? false,
    isLocked: map['is_locked'] as bool? ?? false,
  );
}

class PollOption {
  const PollOption({
    required this.id,
    required this.label,
    required this.voterIds,
  });

  final String id;
  final String label;
  final List<String> voterIds;
}

class ActivityPoll {
  const ActivityPoll({
    required this.id,
    required this.question,
    required this.options,
  });

  final String id;
  final String question;
  final List<PollOption> options;
}

class SharedTripFile {
  const SharedTripFile({
    required this.id,
    required this.name,
    required this.url,
    required this.uploadedBy,
  });

  final String id;
  final String name;
  final String url;
  final String uploadedBy;

  factory SharedTripFile.fromMap(Map<String, dynamic> map) => SharedTripFile(
    id: map['id'] as String,
    name: map['file_name'] as String,
    url: map['file_url'] as String,
    uploadedBy: map['uploaded_by'] as String,
  );
}

class ActivityComment {
  const ActivityComment({
    required this.id,
    required this.activityId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String activityId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  factory ActivityComment.fromMap(Map<String, dynamic> map) => ActivityComment(
    id: map['id'] as String,
    activityId: map['activity_id'] as String,
    authorId: map['author_id'] as String,
    body: map['body'] as String,
    createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
  );
}

class CollaborationNotification {
  const CollaborationNotification({
    required this.id,
    required this.actorId,
    required this.eventType,
    required this.summary,
    required this.createdAt,
  });

  final String id;
  final String actorId;
  final String eventType;
  final String summary;
  final DateTime createdAt;

  factory CollaborationNotification.fromMap(Map<String, dynamic> map) =>
      CollaborationNotification(
        id: map['id'] as String,
        actorId: map['actor_id'] as String,
        eventType: map['event_type'] as String,
        summary: map['summary'] as String,
        createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      );
}

class GroupCollaborationState {
  const GroupCollaborationState({
    required this.tripId,
    required this.currentUserId,
    required this.creatorId,
    required this.isAdmin,
    required this.members,
    required this.messages,
    required this.activities,
    required this.polls,
    required this.files,
    required this.comments,
    required this.notifications,
  });

  final String tripId;
  final String currentUserId;
  final String creatorId;
  final bool isAdmin;
  final List<CollaborationMember> members;
  final List<TripMessage> messages;
  final List<TripActivity> activities;
  final List<ActivityPoll> polls;
  final List<SharedTripFile> files;
  final List<ActivityComment> comments;
  final List<CollaborationNotification> notifications;

  bool get isCreator => currentUserId == creatorId;
  bool get canManageMembers => isCreator || isAdmin;
  bool get isMuted => members
      .where((member) => member.userId == currentUserId)
      .any((member) => member.isMuted);
}
