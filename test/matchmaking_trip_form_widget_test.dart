import 'package:flutter/material.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_models.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/matchmaking_shell_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('create trip calendar opens when the current date is occupied', (
    tester,
  ) async {
    final today = DateUtils.dateOnly(DateTime.now());
    final occupiedTrip = MatchmakingTrip(
      id: 'occupied-trip',
      destination: 'Existing trip',
      startDate: today,
      endDate: today.add(const Duration(days: 2)),
      budget: 100,
      styles: const {'Nature'},
      hostId: 'traveller',
      hostName: 'Traveller',
      hostInitials: 'T',
      imageUrl: '',
      gender: 'Any',
      minAge: 18,
      maxAge: 60,
      vacancies: 2,
      description: '',
      isOwned: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: InteractiveTripFormPage(
            onBack: () {},
            onPublish: (_) {},
            onUploadImage: (_, _, _) async => '',
            hostedTrips: [occupiedTrip],
          ),
        ),
      ),
    );

    final fields = find.byType(TextFormField);
    expect(fields, findsWidgets);

    await tester.tap(fields.at(1));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
