import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_page.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model.dart';

void main() {
  test('updates filter and page through the view model', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(matchmakingViewModelProvider.notifier);
    expect(
      container.read(matchmakingViewModelProvider).availableFilters,
      contains('Adventure'),
    );

    notifier.selectFilter('Adventure');
    notifier.goTo(MatchmakingPage.details);

    final state = container.read(matchmakingViewModelProvider);
    expect(state.selectedFilter, 'Adventure');
    expect(state.page, MatchmakingPage.details);
  });
}
