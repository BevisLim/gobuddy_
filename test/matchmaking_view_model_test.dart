import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_page.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late MatchmakingViewModel notifier;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(matchmakingViewModelProvider.notifier);
  });

  tearDown(() => container.dispose());

  test('does not show fixture trips without a database session', () {
    final state = container.read(matchmakingViewModelProvider);

    expect(state.trips, isEmpty);
    expect(state.discoveryTrips, isEmpty);
    expect(state.applicants, isEmpty);
    expect(state.requests, isEmpty);
  });

  test('cannot create a local-only join request while signed out', () {
    expect(notifier.sendRequest('missing-trip', 'Please add me.'), isFalse);
    expect(container.read(matchmakingViewModelProvider).requests, isEmpty);
  });

  test('navigation and discovery filters remain local UI state', () {
    notifier.goTo(MatchmakingPage.filters);
    notifier.selectFilter('Culture');

    final state = container.read(matchmakingViewModelProvider);
    expect(state.page, MatchmakingPage.filters);
    expect(state.selectedFilter, 'Culture');
  });
}
