import '../../model/matchmaking_models.dart';
import '../../model/matchmaking_notification.dart';
import '../../model/matchmaking_page.dart';

class MatchmakingStateV2 {
  const MatchmakingStateV2(
      {this.page = MatchmakingPage.discover,
      this.selectedFilter = 'All',
      this.availableFilters = const [],
      this.filters = const MatchmakingFilters(),
      this.trips = const [],
      this.applicants = const [],
      this.requests = const [],
      this.notifications = const [],
      this.savedTripIds = const {},
      this.isLoading = false,
      this.errorMessage,
      this.successMessage,
      this.selectedTripId,
      this.selectedApplicantId,
      this.managedTripId});
  final MatchmakingPage page;
  final String selectedFilter;
  final List<String> availableFilters;
  final MatchmakingFilters filters;
  final List<MatchmakingTrip> trips;
  final List<MatchmakingApplicant> applicants;
  final List<JoinRequest> requests;
  final List<MatchmakingNotification> notifications;
  final Set<String> savedTripIds;
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;
  final String? selectedTripId, selectedApplicantId, managedTripId;
  int get unreadNotificationCount =>
      notifications.where((notification) => notification.isUnread).length;

  MatchmakingTrip? get selectedTrip => _tripById(selectedTripId);
  MatchmakingTrip? get managedTrip => _tripById(managedTripId);
  MatchmakingApplicant? get selectedApplicant =>
      applicants.where((item) => item.id == selectedApplicantId).firstOrNull;
  List<MatchmakingTrip> get ownedTrips =>
      trips.where((trip) => trip.isOwned).toList(growable: false);
  List<MatchmakingTrip> get discoveryTrips => trips
      .where((trip) => !trip.isOwned && _matchesFilters(trip))
      .toList(growable: false);
  List<JoinRequest> get managedRequests => requests
      .where((request) => request.tripId == managedTripId)
      .toList(growable: false);
  MatchmakingTrip? _tripById(String? id) =>
      trips.where((trip) => trip.id == id).firstOrNull;

  bool _matchesFilters(MatchmakingTrip trip) {
    final query = filters.destination.trim().toLowerCase();
    if (query.isNotEmpty && !trip.destination.toLowerCase().contains(query)) {
      return false;
    }
    if (trip.budget < filters.minBudget || trip.budget > filters.maxBudget) {
      return false;
    }
    if (filters.startDate != null &&
        trip.endDate.isBefore(filters.startDate!)) {
      return false;
    }
    if (filters.endDate != null && trip.startDate.isAfter(filters.endDate!)) {
      return false;
    }
    if (trip.maxAge < filters.minAge || trip.minAge > filters.maxAge) {
      return false;
    }
    if (filters.gender != 'Any' &&
        trip.gender != 'Any' &&
        trip.gender != filters.gender) {
      return false;
    }
    if (filters.styles.isNotEmpty &&
        !trip.styles.any(filters.styles.contains)) {
      return false;
    }
    return selectedFilter == 'All' || trip.styles.contains(selectedFilter);
  }

  MatchmakingStateV2 copyWith(
          {MatchmakingPage? page,
          String? selectedFilter,
          List<String>? availableFilters,
          MatchmakingFilters? filters,
          List<MatchmakingTrip>? trips,
          List<MatchmakingApplicant>? applicants,
          List<JoinRequest>? requests,
          List<MatchmakingNotification>? notifications,
          Set<String>? savedTripIds,
          bool? isLoading,
          String? errorMessage,
          String? successMessage,
          String? selectedTripId,
          String? selectedApplicantId,
          String? managedTripId,
          bool clearSelectedTrip = false,
          bool clearSelectedApplicant = false,
          bool clearError = false,
          bool clearSuccess = false}) =>
      MatchmakingStateV2(
          page: page ?? this.page,
          selectedFilter: selectedFilter ?? this.selectedFilter,
          availableFilters: availableFilters ?? this.availableFilters,
          filters: filters ?? this.filters,
          trips: trips ?? this.trips,
          applicants: applicants ?? this.applicants,
          requests: requests ?? this.requests,
          notifications: notifications ?? this.notifications,
          savedTripIds: savedTripIds ?? this.savedTripIds,
          isLoading: isLoading ?? this.isLoading,
          errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
          successMessage:
              clearSuccess ? null : successMessage ?? this.successMessage,
          selectedTripId:
              clearSelectedTrip ? null : selectedTripId ?? this.selectedTripId,
          selectedApplicantId: clearSelectedApplicant
              ? null
              : selectedApplicantId ?? this.selectedApplicantId,
          managedTripId: managedTripId ?? this.managedTripId);
}
