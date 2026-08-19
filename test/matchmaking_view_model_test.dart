import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_page.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/state/matchmaking_state.dart';

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

  test('toggles and resets matchmaking filters', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(matchmakingViewModelProvider.notifier);

    notifier.toggleStyle('Culture');
    expect(container.read(matchmakingViewModelProvider).selectedStyles,
        contains('Culture'));
    notifier.resetFilters();
    final state = container.read(matchmakingViewModelProvider);
    expect(state.selectedFilter, 'All');
    expect(state.selectedStyles, isEmpty);
  });

  test('applies advanced matchmaking filters', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(matchmakingViewModelProvider.notifier);
    const filters = MatchmakingFilters(
        destination: 'Kyoto',
        minBudget: 1000,
        maxBudget: 1600,
        styles: {'Culture'});

    notifier.applyFilters(filters);
    final state = container.read(matchmakingViewModelProvider);
    expect(state.filters.destination, 'Kyoto');
    expect(state.filters.styles, {'Culture'});
    expect(state.page, MatchmakingPage.discover);
  });

  test('rejects invalid filters and tabs', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(matchmakingViewModelProvider.notifier);
    expect(() => notifier.selectFilter('Unknown'), throwsArgumentError);
    expect(() => notifier.selectTab(3), throwsRangeError);
  });

  test('validates requests and records applicant decisions', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(matchmakingViewModelProvider.notifier);

    expect(notifier.sendRequest('tokyo', '  '), isFalse);
    expect(notifier.sendRequest('tokyo', ' Let me join! '), isTrue);
    notifier.decideApplicant('priya', ApplicantDecision.accepted);

    final state = container.read(matchmakingViewModelProvider);
    expect(state.requestMessages['tokyo'], 'Let me join!');
    expect(state.applicantDecisions['priya'], ApplicantDecision.accepted);
    expect(state.page, MatchmakingPage.sent);
  });

  test('saves and deletes an edited trip', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(matchmakingViewModelProvider.notifier);
    const trip = MatchmakingTrip(
        destination: 'Seoul, Korea',
        startDate: '01/10/2026',
        endDate: '08/10/2026',
        budget: '2200',
        styles: {'Foodie'},
        gender: 'Any',
        minAge: 24,
        maxAge: 36,
        vacancies: 3,
        description: 'Food and culture trip.');

    notifier.saveTrip(trip);
    expect(container.read(matchmakingViewModelProvider).myTrip.destination,
        'Seoul, Korea');
    expect(container.read(matchmakingViewModelProvider).hasMyTrip, isTrue);
    notifier.deleteTrip();
    expect(container.read(matchmakingViewModelProvider).hasMyTrip, isFalse);
    notifier.deleteListedTrip('bali');
    expect(container.read(matchmakingViewModelProvider).deletedTripIds,
        contains('bali'));
  });
}
