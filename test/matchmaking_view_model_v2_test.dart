import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_models.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_page.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ProviderContainer container;
  late MatchmakingViewModelV2 notifier;
  setUp(() {
    container = ProviderContainer();
    notifier = container.read(matchmakingViewModelV2Provider.notifier);
  });
  tearDown(() => container.dispose());

  test('repository seed data and selected trip stay consistent', () {
    final initial = container.read(matchmakingViewModelV2Provider);
    expect(
        initial.trips.map((trip) => trip.id), containsAll(['tokyo', 'kyoto']));
    notifier.openTrip('kyoto', MatchmakingPage.details);
    final state = container.read(matchmakingViewModelV2Provider);
    expect(state.selectedTrip?.destination, 'Kyoto, Japan');
    expect(state.page, MatchmakingPage.details);
  });

  test('creates, edits, and deletes list-backed trips', () {
    final trip = MatchmakingTrip(
        id: 'seoul',
        destination: 'Seoul, Korea',
        startDate: DateTime(2027, 1, 1),
        endDate: DateTime(2027, 1, 8),
        budget: 2000,
        styles: const {'Foodie'},
        hostId: 'current-user',
        hostName: 'Morgan Lee',
        hostInitials: 'ML',
        imageUrl: '',
        gender: 'Any',
        minAge: 22,
        maxAge: 40,
        vacancies: 3,
        description: 'Food trip.',
        isOwned: true);
    notifier.saveTrip(trip);
    expect(container.read(matchmakingViewModelV2Provider).page,
        MatchmakingPage.myTrips);
    expect(
        container
            .read(matchmakingViewModelV2Provider)
            .ownedTrips
            .any((item) => item.id == 'seoul'),
        isTrue);
    notifier.saveTrip(trip.copyWith(destination: 'Seoul City'));
    expect(
        container
            .read(matchmakingViewModelV2Provider)
            .trips
            .firstWhere((item) => item.id == 'seoul')
            .destination,
        'Seoul City');
    notifier.deleteTrip('seoul');
    expect(
        container
            .read(matchmakingViewModelV2Provider)
            .trips
            .any((item) => item.id == 'seoul'),
        isFalse);
  });

  test('saves trips and prevents duplicate join requests', () {
    notifier.toggleSavedTrip('kyoto');
    expect(container.read(matchmakingViewModelV2Provider).savedTripIds,
        contains('kyoto'));
    expect(notifier.sendRequest('kyoto', 'I would love to join.'), isTrue);
    expect(notifier.sendRequest('kyoto', 'A duplicate'), isFalse);
    expect(container.read(matchmakingViewModelV2Provider).successMessage,
        'Join request sent.');
  });

  test('request decisions update capacity and delete declined requests', () {
    final before = container
        .read(matchmakingViewModelV2Provider)
        .trips
        .firstWhere((trip) => trip.id == 'bali')
        .joined;
    notifier.decideRequest('request-priya', ApplicantDecision.accepted);
    expect(
        container
            .read(matchmakingViewModelV2Provider)
            .trips
            .firstWhere((trip) => trip.id == 'bali')
            .joined,
        before + 1);
    expect(container.read(matchmakingViewModelV2Provider).successMessage,
        contains('added to the group'));
    notifier.decideRequest('request-yuki', ApplicantDecision.declined);
    expect(
        container
            .read(matchmakingViewModelV2Provider)
            .requests
            .any((request) => request.id == 'request-yuki'),
        isFalse);
  });

  test('cannot accept a request when the trip has no spots left', () {
    final fullTrip = container
        .read(matchmakingViewModelV2Provider)
        .trips
        .firstWhere((trip) => trip.id == 'bali')
        .copyWith(joined: 5);
    notifier.saveTrip(fullTrip);

    notifier.decideRequest('request-priya', ApplicantDecision.accepted);

    final state = container.read(matchmakingViewModelV2Provider);
    expect(
        state.requests
            .firstWhere((request) => request.id == 'request-priya')
            .decision,
        ApplicantDecision.pending);
    expect(state.trips.firstWhere((trip) => trip.id == 'bali').joined, 5);
  });

  test('advanced filters are retained and reset', () {
    final filters = MatchmakingFilters(
        destination: 'Kyoto',
        startDate: DateTime(2026, 10, 1),
        styles: const {'Culture'});
    notifier.applyFilters(filters);
    expect(container.read(matchmakingViewModelV2Provider).filters.destination,
        'Kyoto');
    notifier.resetFilters();
    expect(container.read(matchmakingViewModelV2Provider).filters.destination,
        isEmpty);
  });
}
