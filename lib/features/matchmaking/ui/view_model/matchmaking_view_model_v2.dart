import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/matchmaking_models.dart';
import '../../model/matchmaking_notification.dart';
import '../../model/matchmaking_page.dart';
import '../../repository/matchmaking_repository.dart';
import '../state/matchmaking_state_v2.dart';

final matchmakingInitialPageProvider =
    Provider<MatchmakingPage>((ref) => MatchmakingPage.discover);

final matchmakingViewModelV2Provider =
    NotifierProvider<MatchmakingViewModelV2, MatchmakingStateV2>(
        MatchmakingViewModelV2.new);

class MatchmakingViewModelV2 extends Notifier<MatchmakingStateV2> {
  MatchmakingRepository get _repository =>
      ref.read(matchmakingRepositoryProvider);
  @override
  MatchmakingStateV2 build() {
    final connected = _repository.hasAuthenticatedUser;
    if (connected) unawaited(Future<void>.microtask(refresh));
    return MatchmakingStateV2(
        page: ref.watch(matchmakingInitialPageProvider),
        availableFilters: _repository.discoveryFilters,
        trips: connected ? const [] : _repository.trips,
        applicants: _repository.applicants,
        requests: _repository.requests,
        isLoading: connected);
  }

  Future<void> refresh() async {
    if (!_repository.hasAuthenticatedUser) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final trips = await _repository.fetchTrips();
      final savedIds = await _repository.fetchSavedTripIds();
      final requests = await _repository.fetchJoinRequests();
      final applicants = await _repository.fetchApplicants();
      final notifications = await _repository.fetchNotifications();
      state = state.copyWith(
          trips: trips,
          requests: requests,
          applicants: applicants,
          notifications: notifications,
          savedTripIds: savedIds,
          isLoading: false,
          clearError: true);
    } catch (error) {
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
    final text = message.trim();
    if (text.isEmpty || text.length > 500) return false;
    if (state.requests.any((request) =>
        request.tripId == tripId &&
        request.applicantId == _repository.currentUserId)) {
      return false;
    }
    final requests = [
      ...state.requests,
      JoinRequest(
          id: 'request-${DateTime.now().microsecondsSinceEpoch}',
          tripId: tripId,
          applicantId: _repository.currentUserId,
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
