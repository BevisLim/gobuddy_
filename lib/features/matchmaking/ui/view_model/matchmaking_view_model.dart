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
    state = state.copyWith(selectedFilter: filter);
  }

  void selectTab(int tab) {
    final page = switch (tab) {
      0 => MatchmakingPage.discover,
      1 => MatchmakingPage.myTrips,
      _ => MatchmakingPage.profile,
    };
    state = state.copyWith(selectedTab: tab, page: page);
  }
}
