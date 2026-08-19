import 'package:flutter/material.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/model/matchmaking_page.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/matchmaking_shell_screen.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/view_model/matchmaking_view_model_v2.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('My Trips route opens the My Trips page', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          matchmakingInitialPageProvider.overrideWithValue(
            MatchmakingPage.myTrips,
          ),
        ],
        child: const MaterialApp(home: MatchmakingShellScreen()),
      ),
    );

    expect(find.text('My trips'), findsOneWidget);
    expect(find.text('+ Create a new trip'), findsOneWidget);
  });

  testWidgets('discovery style chips filter visible cards', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: MatchmakingShellScreen())));
    await tester.pump();
    expect(find.text('Tokyo, Japan'), findsOneWidget);
    expect(find.text('Kyoto, Japan'), findsOneWidget);

    await tester.tap(find.text('Culture').first);
    await tester.pump();
    expect(find.text('Tokyo, Japan'), findsNothing);
    expect(find.text('Kyoto, Japan'), findsOneWidget);
  });

  testWidgets('bottom navigation opens My Trips', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: MatchmakingShellScreen())));
    await tester.tap(find.byIcon(Icons.luggage_outlined));
    await tester.pump();

    expect(find.text('My trips'), findsOneWidget);
    expect(find.text('+ Create a new trip'), findsOneWidget);
  });

  testWidgets('back from create returns to discovery', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: MatchmakingShellScreen())));
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    expect(find.text('Create Trip'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pump();
    expect(find.text('GoBuddy'), findsOneWidget);
    expect(find.text('Tokyo, Japan'), findsOneWidget);
  });
}
