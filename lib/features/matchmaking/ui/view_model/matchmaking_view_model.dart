import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../model/matchmaking_page.dart';
import '../../repository/matchmaking_repository.dart';
import '../state/matchmaking_state.dart';

final matchmakingViewModelProvider =
    NotifierProvider<MatchmakingViewModel, MatchmakingState>(
  MatchmakingViewModel.new,
);

class MatchmakingViewModel extends Notifier<MatchmakingState> {
  @override
  MatchmakingState build() {
    final repository = ref.read(matchmakingRepositoryProvider);
    return MatchmakingState(availableFilters: repository.discoveryFilters);
  }

  void goTo(MatchmakingPage page) => state = state.copyWith(page: page);

  void selectFilter(String filter) {
    if (!state.availableFilters.contains(filter)) {
      throw ArgumentError.value(filter, 'filter', 'Unknown discovery filter');
    }
    state = state.copyWith(selectedFilter: filter);
  }

  void toggleStyle(String style) {
    final styles = ref.read(matchmakingRepositoryProvider).travelStyles;
    if (!styles.contains(style)) {
      throw ArgumentError.value(style, 'style', 'Unknown travel style');
    }
    final selected = {...state.selectedStyles};
    selected.contains(style) ? selected.remove(style) : selected.add(style);
    state = state.copyWith(selectedStyles: selected);
  }

  void resetFilters() => state = state.copyWith(
        selectedFilter: 'All',
        selectedStyles: <String>{},
        filters: const MatchmakingFilters(),
      );

  void applyFilters(MatchmakingFilters filters) => state = state.copyWith(
        filters: filters,
        selectedFilter: 'All',
        page: MatchmakingPage.discover,
      );

  void toggleSavedTrip(String tripId) {
    final saved = {...state.savedTripIds};
    saved.contains(tripId) ? saved.remove(tripId) : saved.add(tripId);
    state = state.copyWith(savedTripIds: saved);
  }

  bool sendRequest(String tripId, String message) {
    final normalized = message.trim();
    if (normalized.isEmpty || normalized.length > 500) return false;
    state = state.copyWith(
      requestMessages: {...state.requestMessages, tripId: normalized},
      page: MatchmakingPage.sent,
    );
    return true;
  }

  void decideApplicant(String applicantId, ApplicantDecision decision) {
    state = state.copyWith(
      applicantDecisions: {...state.applicantDecisions, applicantId: decision},
    );
  }

  void saveTrip(MatchmakingTrip trip) => state = state.copyWith(
        myTrip: trip,
        hasMyTrip: true,
        page: MatchmakingPage.myTrips,
      );

  void deleteTrip() => state = state.copyWith(
        hasMyTrip: false,
        page: MatchmakingPage.myTrips,
      );

  void deleteListedTrip(String tripId) => state = state.copyWith(
        deletedTripIds: {...state.deletedTripIds, tripId},
      );

  void selectTab(int tab) {
    if (tab < 0 || tab > 2) {
      throw RangeError.range(tab, 0, 2, 'tab');
    }
    final page = switch (tab) {
      0 => MatchmakingPage.discover,
      1 => MatchmakingPage.myTrips,
      _ => MatchmakingPage.profile,
    };
    state = state.copyWith(selectedTab: tab, page: page);
  }
}
