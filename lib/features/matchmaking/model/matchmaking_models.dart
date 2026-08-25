enum TripStatus { active, closed, draft }

enum ApplicantDecision { pending, accepted, held, declined, cancelled }

class MatchmakingTrip {
  const MatchmakingTrip({
    required this.id,
    required this.destination,
    required this.startDate,
    required this.endDate,
    required this.budget,
    required this.styles,
    required this.hostId,
    required this.hostName,
    required this.hostInitials,
    required this.imageUrl,
    required this.gender,
    required this.minAge,
    required this.maxAge,
    required this.vacancies,
    required this.description,
    this.joined = 0,
    this.groupMemberCount = 0,
    this.verifiedHost = true,
    this.status = TripStatus.active,
    this.isOwned = false,
  });

  final String id, destination, hostId, hostName, hostInitials, imageUrl;
  final DateTime startDate, endDate;
  final int budget, minAge, maxAge, vacancies, joined, groupMemberCount;
  final Set<String> styles;
  final String gender, description;
  final bool verifiedHost, isOwned;
  final TripStatus status;

  int get spotsLeft => (vacancies - joined).clamp(0, vacancies);
  bool get isDiscoverable {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    return status == TripStatus.active &&
        !startDay.isBefore(today) &&
        spotsLeft > 0;
  }

  MatchmakingTrip copyWith(
          {String? destination,
          DateTime? startDate,
          DateTime? endDate,
          int? budget,
          Set<String>? styles,
          String? gender,
          int? minAge,
          int? maxAge,
          int? vacancies,
          String? description,
          int? joined,
          int? groupMemberCount,
          TripStatus? status}) =>
      MatchmakingTrip(
          id: id,
          destination: destination ?? this.destination,
          startDate: startDate ?? this.startDate,
          endDate: endDate ?? this.endDate,
          budget: budget ?? this.budget,
          styles: styles ?? this.styles,
          hostId: hostId,
          hostName: hostName,
          hostInitials: hostInitials,
          imageUrl: imageUrl,
          gender: gender ?? this.gender,
          minAge: minAge ?? this.minAge,
          maxAge: maxAge ?? this.maxAge,
          vacancies: vacancies ?? this.vacancies,
          description: description ?? this.description,
          joined: joined ?? this.joined,
          groupMemberCount: groupMemberCount ?? this.groupMemberCount,
          verifiedHost: verifiedHost,
          status: status ?? this.status,
          isOwned: isOwned);
}

class MatchmakingApplicant {
  const MatchmakingApplicant(
      {required this.id,
      required this.name,
      required this.initials,
      required this.age,
      required this.gender,
      required this.languages,
      required this.styles,
      required this.bio,
      required this.introduction,
      required this.trips,
      required this.rating,
      this.verified = true});
  final String id, name, initials, gender, bio, introduction;
  final int age, trips;
  final double rating;
  final Set<String> languages, styles;
  final bool verified;
}

class JoinRequest {
  const JoinRequest(
      {required this.id,
      required this.tripId,
      required this.applicantId,
      required this.message,
      this.decision = ApplicantDecision.pending});
  final String id, tripId, applicantId, message;
  final ApplicantDecision decision;
  JoinRequest copyWith({ApplicantDecision? decision}) => JoinRequest(
      id: id,
      tripId: tripId,
      applicantId: applicantId,
      message: message,
      decision: decision ?? this.decision);
}

class MatchmakingFilters {
  const MatchmakingFilters(
      {this.destination = '',
      this.startDate,
      this.endDate,
      this.minBudget = 0,
      this.maxBudget = 10000,
      this.minAge = 18,
      this.maxAge = 80,
      this.gender = 'Any',
      this.styles = const {}});
  final String destination;
  final DateTime? startDate, endDate;
  final int minBudget, maxBudget, minAge, maxAge;
  final String gender;
  final Set<String> styles;
}
