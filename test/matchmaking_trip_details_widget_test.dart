import 'package:flutter/material.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_models.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/matchmaking_shell_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final trip = MatchmakingTrip(
    id: 'trip-id',
    destination: 'Osaka, Japan',
    startDate: DateTime(2026, 9, 2),
    endDate: DateTime(2026, 9, 8),
    budget: 10000,
    styles: const {'Culture'},
    hostId: 'owner-id',
    hostName: 'Trip owner',
    hostInitials: 'TO',
    imageUrl: '',
    gender: 'Any',
    minAge: 18,
    maxAge: 60,
    vacancies: 2,
    description: 'Test trip',
  );

  Widget page({required bool canOpenGroup}) => MaterialApp(
    home: Scaffold(
      body: TripDetailsPage(
        trip: trip,
        canOpenGroup: canOpenGroup,
        onBack: () {},
        onRequest: () {},
        onOpenGroup: () {},
      ),
    ),
  );

  testWidgets('unjoined traveller cannot open group workspace', (tester) async {
    await tester.pumpWidget(page(canOpenGroup: false));

    expect(find.text('Open group workspace'), findsNothing);
    expect(find.text('Request to Join'), findsOneWidget);
  });

  testWidgets('trip member can open group workspace', (tester) async {
    await tester.pumpWidget(page(canOpenGroup: true));

    expect(find.text('Open group workspace'), findsOneWidget);
    expect(find.text('Request to Join'), findsNothing);
  });
}
