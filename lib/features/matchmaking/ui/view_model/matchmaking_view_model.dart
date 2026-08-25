import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/matchmaking_models.dart';
import '../../model/matchmaking_validation.dart';
import '../../model/matchmaking_notification.dart';
import '../../model/matchmaking_page.dart';
import '../../repository/matchmaking_repository.dart';
import '../state/matchmaking_state.dart';

final matchmakingInitialPageProvider =
    Provider<MatchmakingPage>((ref) => MatchmakingPage.discover);

final matchmakingViewModelProvider =
    NotifierProvider<MatchmakingViewModel, MatchmakingState>(
        MatchmakingViewModel.new);

class MatchmakingViewModel extends Notifier<MatchmakingState> {
  MatchmakingRepository get _repository =>
      ref.read(matchmakingRepositoryProvider);
  @override
  MatchmakingState build() {
    final connected = _repository.hasAuthenticatedUser;
    if (connected) unawaited(Future<void>.microtask(refresh));
    return MatchmakingState(
        page: ref.watch(matchmakingInitialPageProvider),
        availableFilters: _repository.discoveryFilters,
        currentUserId: connected ? _repository.currentUserId : '',
        trips: const [],
        applicants: const [],
        requests: const [],
        isLoading: connected);
  }

  Future<void> refresh() async {
    if (!_repository.hasAuthenticatedUser) return;
    final userId = _repository.currentUserId;
    if (userId.isEmpty) return;

    // Clear account-scoped state if Supabase changed users while this provider
    // remained alive in the root ProviderScope.
    if (state.currentUserId != userId) {
      state = MatchmakingState(
          page: state.page,
          selectedFilter: state.selectedFilter,
          availableFilters: _repository.discoveryFilters,
          filters: state.filters,
          currentUserId: userId,
          isLoading: true);
    } else {
      state = state.copyWith(isLoading: true, clearError: true);
    }
    try {
      final trips = await _repository.fetchTrips();
      final savedIds = await _repository.fetchSavedTripIds();
      final requests = await _repository.fetchJoinRequests();
      final joinedTripIds = await _repository.fetchJoinedTripIds();
      final loadedApplicants = await _repository.fetchApplicants();
      final applicantsById = {
        for (final applicant in loadedApplicants) applicant.id: applicant,
      };
      // Legacy/auth-only users can have a request without a readable public
      // profile. Keep the owner's request inbox usable instead of crashing.
      for (final request in requests) {
        applicantsById.putIfAbsent(
          request.applicantId,
          () => MatchmakingApplicant(
            id: request.applicantId,
            name: 'Profile unavailable',
            initials: '?',
            age: 18,
            gender: 'Prefer not to say',
            languages: const {},
            styles: const {},
            bio: 'This traveller has not completed a public profile.',
            introduction: request.message,
            trips: 0,
            rating: 0,
            verified: false,
          ),
        );
      }
      final applicants = applicantsById.values.toList(growable: false);
      final notifications = await _repository.fetchNotifications();
      // Do not publish results belonging to a session that has since ended or
      // been replaced by another account.
      if (_repository.currentUserId != userId) return;
      state = state.copyWith(
          currentUserId: userId,
          trips: trips,
          requests: requests,
          joinedTripIds: joinedTripIds,
          applicants: applicants,
          notifications: notifications,
          savedTripIds: savedIds,
          isLoading: false,
          clearError: true);
    } catch (error) {
      if (_repository.currentUserId != userId) return;
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  void goTo(MatchmakingPage page) => state = state.copyWith(page: page);
  void clearSuccessMessage() => state = state.copyWith(clearSuccess: true);
  Future<void> markNotificationsRead() async {
    if (!_repository.hasAuthenticatedUser ||
        state.unreadNotificationCount == 0) {
      return;
    }
    try {
      await _repository.markNotificationsRead();
      final now = DateTime.now();
      state = state.copyWith(notifications: [
        for (final notification in state.notifications)
          MatchmakingNotification(
              id: notification.id,
              title: notification.title,
              body: notification.body,
              tripId: notification.tripId,
              createdAt: notification.createdAt,
              readAt: notification.readAt ?? now)
      ]);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  void selectFilter(String value) {
    if (!state.availableFilters.contains(value)) {
      throw ArgumentError.value(value, 'filter');
    }
    state = state.copyWith(selectedFilter: value);
  }

  void applyFilters(MatchmakingFilters value) => state = state.copyWith(
      filters: value, selectedFilter: 'All', page: MatchmakingPage.discover);
  void resetFilters() => state = state.copyWith(
      filters: const MatchmakingFilters(), selectedFilter: 'All');

  void openTrip(String id, MatchmakingPage page) {
    if (!state.trips.any((trip) => trip.id == id)) return;
    state = state.copyWith(selectedTripId: id, page: page);
  }

  void openRequests(String tripId) => state =
      state.copyWith(managedTripId: tripId, page: MatchmakingPage.manage);
  void openApplicant(String applicantId) => state = state.copyWith(
      selectedApplicantId: applicantId, page: MatchmakingPage.applicant);

  void toggleSavedTrip(String id) {
    final ids = {...state.savedTripIds};
    ids.contains(id) ? ids.remove(id) : ids.add(id);
    state = state.copyWith(savedTripIds: ids);
    if (_repository.hasAuthenticatedUser) {
      unawaited(_saveBookmark(id, ids.contains(id)));
    }
  }

  Future<void> _saveBookmark(String id, bool saved) async {
    try {
      await _repository.setTripSaved(id, saved: saved);
    } catch (error) {
      final ids = {...state.savedTripIds};
      saved ? ids.remove(id) : ids.add(id);
      state = state.copyWith(savedTripIds: ids, errorMessage: error.toString());
    }
  }

  void saveTrip(MatchmakingTrip trip) {
    try {
      MatchmakingValidation.validateTrip(trip);
    } on MatchmakingValidationException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return;
    }
    final index = state.trips.indexWhere((item) => item.id == trip.id);
    final trips = [...state.trips];
    if (index < 0) {
      trips.add(trip);
    } else {
      trips[index] = trip;
    }
    state = state.copyWith(
        trips: trips, page: MatchmakingPage.myTrips, selectedTripId: trip.id);
    if (_repository.hasAuthenticatedUser) unawaited(_persistTrip(trip));
  }

  Future<void> _persistTrip(MatchmakingTrip trip) async {
    try {
      await _repository.saveTrip(trip);
      await refresh();
    } catch (error) {
      // Restore the server-backed list after an optimistic create/edit fails.
      await refresh();
      state = state.copyWith(errorMessage: error.toString());
    }
  }

  void deleteTrip(String id) {
    state = state.copyWith(
        trips: state.trips.where((trip) => trip.id != id).toList(),
        requests:
            state.requests.where((request) => request.tripId != id).toList(),
        savedTripIds: {...state.savedTripIds}..remove(id),
        page: MatchmakingPage.myTrips,
        clearSelectedTrip: true);
    if (_repository.hasAuthenticatedUser) unawaited(_deletePersistedTrip(id));
  }

  Future<void> _deletePersistedTrip(String id) async {
    try {
      await _repository.deleteTrip(id);
    } catch (error) {
      state = state.copyWith(errorMessage: error.toString());
      await refresh();
    }
  }

  bool sendRequest(String tripId, String message) {
    final trip = state.trips.where((item) => item.id == tripId).firstOrNull;
    if (trip == null || trip.isOwned || !trip.isDiscoverable) return false;
    late final String text;
    try {
      text = MatchmakingValidation.normalizeRequestMessage(message);
    } on MatchmakingValidationException catch (error) {
      state = state.copyWith(errorMessage: error.message);
      return false;
    }
    final applicantId = state.currentUserId;
    if (applicantId.isEmpty) {
      state = state.copyWith(errorMessage: 'Please sign in first.');
      return false;
    }
    if (state.requests.any((request) =>
        request.tripId == tripId &&
        request.applicantId == applicantId &&
        const {
          ApplicantDecision.pending,
          ApplicantDecision.held,
          ApplicantDecision.accepted,
        }.contains(request.decision))) {
      return false;
    }
    final requests = [
      ...state.requests,
      JoinRequest(
          id: 'request-${DateTime.now().microsecondsSinceEpoch}',
          tripId: tripId,
          applicantId: applicantId,
          message: text)
    ];
    state = state.copyWith(requests: requests, page: MatchmakingPage.sent);
    if (_repository.hasAuthenticatedUser) {
      unawaited(_persistJoinRequest(tripId, text));
    } else {
      state = state.copyWith(successMessage: 'Join request sent.');
    }
    return true;
  }

  Future<void> _persistJoinRequest(String tripId, String message) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.sendJoinRequest(tripId, message);
      await refresh();
      state = state.copyWith(successMessage: 'Join request sent.');
    } catch (error) {
      await refresh();
      state = state.copyWith(isLoading: false, errorMessage: error.toString());
    }
  }

  Future<void> cancelRequest(String requestId) async {
    final request =
        state.requests.where((item) => item.id == requestId).firstOrNull;
    if (request == null ||
        !const {ApplicantDecision.pending, ApplicantDecision.held}
            .contains(request.decision)) {
      return;
    }
    final previousRequests = state.requests;
    state = state.copyWith(
      requests: previousRequests
          .where((item) => item.id != requestId)
          .toList(growable: false),
      clearError: true,
    );
    try {
      await _repository.cancelJoinRequest(requestId);
      state = state.copyWith(successMessage: 'Join request cancelled.');
    } catch (error) {
      state = state.copyWith(
        requests: previousRequests,
        errorMessage: error.toString(),
      );
    }
  }

  void decideRequest(String requestId, ApplicantDecision decision) {
    final current =
        state.requests.where((item) => item.id == requestId).firstOrNull;
    if (current == null) return;
    if (decision == ApplicantDecision.declined) {
      state = state.copyWith(
          requests:
              state.requests.where((item) => item.id != requestId).toList());
      if (_repository.hasAuthenticatedUser) {
        unawaited(_persistRequestDecision(requestId, decision));
      }
      return;
    }
    final tripIndex =
        state.trips.indexWhere((trip) => trip.id == current.tripId);
    final trips = [...state.trips];
    if (tripIndex >= 0) {
      final trip = trips[tripIndex];
      final accepting = decision == ApplicantDecision.accepted &&
          current.decision != ApplicantDecision.accepted;
      final removingAcceptance =
          current.decision == ApplicantDecision.accepted &&
              decision != ApplicantDecision.accepted;
      if (accepting && trip.spotsLeft == 0) return;
      trips[tripIndex] = trip.copyWith(
          joined: trip.joined +
              (accepting
                  ? 1
                  : removingAcceptance
                      ? -1
                      : 0));
    }
    state = state.copyWith(trips: trips, requests: [
      for (final request in state.requests)
        if (request.id == requestId)
          request.copyWith(decision: decision)
        else
          request
    ]);
    if (_repository.hasAuthenticatedUser) {
      unawaited(_persistRequestDecision(requestId, decision));
    } else {
      state = state.copyWith(
          successMessage: decision == ApplicantDecision.accepted
              ? 'Request accepted. The traveller was added to the group.'
              : 'Request updated.');
    }
  }

  Future<void> _persistRequestDecision(
      String requestId, ApplicantDecision decision) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _repository.decideJoinRequest(requestId, decision);
      await refresh();
      state = state.copyWith(
          successMessage: decision == ApplicantDecision.accepted
              ? 'Request accepted. The traveller was added to the group.'
              : 'Request updated.');
    } catch (error) {
      await refresh();
      state = state.copyWith(errorMessage: error.toString());
    }
  }
}
