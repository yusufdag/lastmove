import 'package:flutter_test/flutter_test.dart';
import 'package:last_move/app.dart';
import 'package:last_move/game/services/tutorial_service.dart';
import 'package:last_move/ui/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps the app and lets the async preference load settle.
Future<void> pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(const LastMoveApp());
  await tester.pump();
  await tester.pump();
}

/// Taps PLAY and waits for the route transition.
Future<void> tapPlay(WidgetTester tester) async {
  await tester.tap(find.text('PLAY'));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

/// Text inside the tutorial card.
///
/// Scoped on purpose: the future preview strip is also labelled "NEXT" and the
/// HUD carries the game title "LAST MOVE", so bare `find.text` calls would match
/// more than the tutorial.
Finder tutorialText(String label) => find.descendant(
  of: find.byType(TutorialOverlay),
  matching: find.text(label),
);

/// Walks through every tutorial card with NEXT, finishing with START.
Future<void> completeTutorial(WidgetTester tester) async {
  for (var i = 0; i < kTutorialSteps.length - 1; i++) {
    await tester.tap(tutorialText('NEXT'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }
  await tester.tap(tutorialText('START'));
  await tester.pump();
}

/// The tutorial flag as it is actually written to disk.
Future<bool> tutorialSeenOnDisk() async {
  final preferences = await SharedPreferences.getInstance();
  return preferences.getBool(TutorialService.hasSeenTutorialKey) ?? false;
}
