import '../../model/matchmaking_page.dart';

enum ApplicantDecision { pending, accepted, held, declined }

class MatchmakingTrip {
  const MatchmakingTrip(
      {required this.destination,
      required this.startDate,
      required this.endDate,
      required this.budget,
      required this.styles,
      required this.gender,
      required this.minAge,
      required this.maxAge,
      required this.vacancies,
      required this.description});

  final String destination, startDate, endDate, budget, gender, description;
  final Set<String> styles;
  final int minAge, maxAge, vacancies;
}

const defaultMatchmakingTrip = MatchmakingTrip(
  destination: 'Tokyo, Japan',
  startDate: '12/08/2025',
  endDate: '20/08/2025',
  budget: '1800',
  styles: {'Adventure', 'Nature'},
  gender: 'Any',
  minAge: 22,
  maxAge: 40,
  vacancies: 2,
  description: 'Looking for a calm travel companion to explore Tokyo.',
);

class MatchmakingFilters {
  const MatchmakingFilters(
      {this.destination = '',
      this.startDate,
      this.endDate,
      this.minBudget = 500,
      this.maxBudget = 2500,
      this.minAge = 22,
      this.maxAge = 35,
      this.gender = 'Any',
      this.styles = const {}});
  final String destination;
  final DateTime? startDate, endDate;
  final int minBudget, maxBudget, minAge, maxAge;
  final String gender;
  final Set<String> styles;
}

class MatchmakingState {
  const MatchmakingState({
    this.page = MatchmakingPage.discover,
    this.selectedTab = 0,
    this.selectedFilter = 'All',
    this.selectedStyles = const {'Adventure', 'Nature'},
    this.availableFilters = const [],
    this.savedTripIds = const {},
    this.requestMessages = const {},
    this.applicantDecisions = const {},
    this.myTrip = defaultMatchmakingTrip,
    this.hasMyTrip = true,
    this.deletedTripIds = const {},
    this.filters = const MatchmakingFilters(),
  });

  final MatchmakingPage page;
  final int selectedTab;
  final String selectedFilter;
  final Set<String> selectedStyles;
  final List<String> availableFilters;
  final Set<String> savedTripIds;
  final Map<String, String> requestMessages;
  final Map<String, ApplicantDecision> applicantDecisions;
  final MatchmakingTrip myTrip;
  final bool hasMyTrip;
  final Set<String> deletedTripIds;
  final MatchmakingFilters filters;

  MatchmakingState copyWith({
    MatchmakingPage? page,
    int? selectedTab,
    String? selectedFilter,
    Set<String>? selectedStyles,
    List<String>? availableFilters,
    Set<String>? savedTripIds,
    Map<String, String>? requestMessages,
    Map<String, ApplicantDecision>? applicantDecisions,
    MatchmakingTrip? myTrip,
    bool? hasMyTrip,
    Set<String>? deletedTripIds,
    MatchmakingFilters? filters,
  }) {
    return MatchmakingState(
      page: page ?? this.page,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedStyles: selectedStyles ?? this.selectedStyles,
      availableFilters: availableFilters ?? this.availableFilters,
      savedTripIds: savedTripIds ?? this.savedTripIds,
      requestMessages: requestMessages ?? this.requestMessages,
      applicantDecisions: applicantDecisions ?? this.applicantDecisions,
      myTrip: myTrip ?? this.myTrip,
      hasMyTrip: hasMyTrip ?? this.hasMyTrip,
      deletedTripIds: deletedTripIds ?? this.deletedTripIds,
      filters: filters ?? this.filters,
    );
  }
}
