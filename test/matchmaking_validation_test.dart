import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_models.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_validation.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/state/matchmaking_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MatchmakingTrip trip({
    String id = 'trip',
    DateTime? startDate,
    DateTime? endDate,
    int vacancies = 3,
    int joined = 0,
    TripStatus status = TripStatus.active,
    bool isOwned = false,
  }) {
    final start = startDate ?? DateTime(2030, 1, 10);
    return MatchmakingTrip(
      id: id,
      destination: 'Penang, Malaysia',
      startDate: start,
      endDate: endDate ?? start.add(const Duration(days: 4)),
      budget: 900,
      styles: const {'Foodie'},
      hostId: 'host',
      hostName: 'Traveller',
      hostInitials: 'T',
      imageUrl: '',
      gender: 'Any',
      minAge: 21,
      maxAge: 40,
      vacancies: vacancies,
      joined: joined,
      description: 'A relaxed food and culture trip.',
      status: status,
      isOwned: isOwned,
    );
  }

  test('normalizes valid request messages and rejects invalid messages', () {
    expect(MatchmakingValidation.normalizeRequestMessage('  Hello  '), 'Hello');
    expect(
      () => MatchmakingValidation.normalizeRequestMessage('   '),
      throwsA(isA<MatchmakingValidationException>()),
    );
    expect(
      () => MatchmakingValidation.normalizeRequestMessage(
          List.filled(501, 'x').join()),
      throwsA(isA<MatchmakingValidationException>()),
    );
  });

  test('rejects past and reversed trip dates', () {
    expect(
      () => MatchmakingValidation.validateTrip(
        trip(startDate: DateTime(2029, 12, 31)),
        now: DateTime(2030, 1, 1),
      ),
      throwsA(isA<MatchmakingValidationException>()),
    );
    expect(
      () => MatchmakingValidation.validateTrip(
        trip(
          startDate: DateTime(2030, 1, 10),
          endDate: DateTime(2030, 1, 9),
        ),
        now: DateTime(2030, 1, 1),
      ),
      throwsA(isA<MatchmakingValidationException>()),
    );
  });

  test('allows a trip without a description', () {
    final withoutDescription = trip().copyWith(description: '');

    expect(
      () => MatchmakingValidation.validateTrip(
        withoutDescription,
        now: DateTime(2030, 1, 1),
      ),
      returnsNormally,
    );
  });

  test('discovery excludes full, closed, owned, joined, and requested trips',
      () {
    final available = trip();
    final requested =
        trip(id: 'requested').copyWith(destination: 'Requested trip');
    final joined = trip(id: 'joined').copyWith(destination: 'Joined trip');
    final state = MatchmakingState(
      currentUserId: 'member',
      joinedTripIds: {joined.id},
      requests: [
        JoinRequest(
          id: 'request',
          tripId: requested.id,
          applicantId: 'member',
          message: 'Please add me.',
        ),
      ],
      trips: [
        available,
        trip(vacancies: 2, joined: 2),
        trip(status: TripStatus.closed),
        requested,
        joined,
        MatchmakingTrip(
          id: 'owned',
          destination: available.destination,
          startDate: available.startDate,
          endDate: available.endDate,
          budget: available.budget,
          styles: available.styles,
          hostId: available.hostId,
          hostName: available.hostName,
          hostInitials: available.hostInitials,
          imageUrl: available.imageUrl,
          gender: available.gender,
          minAge: available.minAge,
          maxAge: available.maxAge,
          vacancies: available.vacancies,
          description: available.description,
          isOwned: true,
        ),
      ],
    );

    expect(state.discoveryTrips.map((item) => item.id), ['trip']);
  });

  test('group chats include owned and joined trips for the current account', () {
    final state = MatchmakingState(
      trips: [
        trip(id: 'owned', isOwned: true),
        trip(id: 'joined'),
        trip(id: 'unrelated'),
      ],
      joinedTripIds: const {'joined'},
    );

    expect(state.groupTrips.map((item) => item.id), ['owned', 'joined']);
  });
}
