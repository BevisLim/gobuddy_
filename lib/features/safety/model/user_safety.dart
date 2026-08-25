enum UserReportReason {
  harassment('Harassment or bullying'),
  hateSpeech('Hate speech'),
  inappropriateContent('Inappropriate content'),
  scam('Scam or fraud'),
  impersonation('Impersonation'),
  other('Other');

  const UserReportReason(this.label);
  final String label;
}

class BlockedUser {
  const BlockedUser({
    required this.userId,
    required this.displayName,
    required this.blockedAt,
    this.avatarUrl,
  });

  final String userId;
  final String displayName;
  final String? avatarUrl;
  final DateTime blockedAt;
}

class UserReport {
  const UserReport({
    required this.id,
    required this.reporterId,
    required this.reportedUserId,
    required this.reason,
    required this.createdAt,
    required this.status,
    this.description,
  });

  final String id;
  final String reporterId;
  final String reportedUserId;
  final UserReportReason reason;
  final String? description;
  final DateTime createdAt;
  final String status;
}
