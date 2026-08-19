class CollaborationMember {
  const CollaborationMember({required this.userId, this.mutedUntil});

  final String userId;
  final DateTime? mutedUntil;

  bool get isMuted => mutedUntil?.isAfter(DateTime.now()) ?? false;

  factory CollaborationMember.fromMap(Map<String, dynamic> map) =>
      CollaborationMember(
        userId: map['user_id'] as String,
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
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime sentAt;

  factory TripMessage.fromMap(Map<String, dynamic> map) => TripMessage(
        id: map['id'] as String,
        senderId: map['sender_id'] as String,
        body: map['body'] as String,
        sentAt: DateTime.parse(map['sent_at'] as String).toLocal(),
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
  const PollOption({required this.id, required this.label, required this.voterIds});

  final String id;
  final String label;
  final List<String> voterIds;
}

class ActivityPoll {
  const ActivityPoll({required this.id, required this.question, required this.options});

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

class GroupCollaborationState {
  const GroupCollaborationState({
    required this.tripId,
    required this.currentUserId,
    required this.creatorId,
    required this.members,
    required this.messages,
    required this.activities,
    required this.polls,
    required this.files,
  });

  final String tripId;
  final String currentUserId;
  final String creatorId;
  final List<CollaborationMember> members;
  final List<TripMessage> messages;
  final List<TripActivity> activities;
  final List<ActivityPoll> polls;
  final List<SharedTripFile> files;

  bool get isCreator => currentUserId == creatorId;
  bool get isMuted => members
      .where((member) => member.userId == currentUserId)
      .any((member) => member.isMuted);
}
