import 'package:flutter/material.dart';
import 'package:flutter_mvvm_riverpod/features/matchmaking/ui/matchmaking_shell_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

  testWidgets('My Trips is reachable and has create action', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ProviderScope(
        child: MaterialApp(home: MatchmakingShellScreen())));
    await tester.tap(find.byTooltip('My Trips'));
    await tester.pump();
    expect(find.text('My trips'), findsOneWidget);
    expect(find.text('+ Create a new trip'), findsOneWidget);
  });
}
