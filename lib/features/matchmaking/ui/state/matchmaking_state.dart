import '../../model/matchmaking_page.dart';

class MatchmakingState {
  const MatchmakingState({
    this.page = MatchmakingPage.discover,
    this.selectedTab = 0,
    this.selectedFilter = 'All',
    this.selectedStyles = const {'Adventure', 'Nature'},
    this.availableFilters = const [],
  });

  final MatchmakingPage page;
  final int selectedTab;
  final String selectedFilter;
  final Set<String> selectedStyles;
  final List<String> availableFilters;

  MatchmakingState copyWith({
    MatchmakingPage? page,
    int? selectedTab,
    String? selectedFilter,
    Set<String>? selectedStyles,
    List<String>? availableFilters,
  }) {
    return MatchmakingState(
      page: page ?? this.page,
      selectedTab: selectedTab ?? this.selectedTab,
      selectedFilter: selectedFilter ?? this.selectedFilter,
      selectedStyles: selectedStyles ?? this.selectedStyles,
      availableFilters: availableFilters ?? this.availableFilters,
    );
  }
}
