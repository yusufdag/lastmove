import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_move/ui/screens/how_to_play_screen.dart';
import 'package:last_move/ui/tile_legend.dart';
import 'package:last_move/ui/tutorial_overlay.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/ui_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('the main menu offers HOW TO PLAY next to PLAY', (tester) async {
    await pumpApp(tester);

    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(find.text('BEST SCORE'), findsOneWidget);
    expect(find.text('BEST LEVEL'), findsOneWidget);
  });

  testWidgets('HOW TO PLAY opens, explains the tiles and closes again', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HowToPlayScreen), findsOneWidget);

    // The goal is stated first, in the player's own words.
    expect(find.text('GOAL'), findsOneWidget);
    expect(find.text('Survive until the exit opens.'), findsOneWidget);
    expect(
      find.text('Reach the Exit Tile to complete the level.'),
      findsOneWidget,
    );

    // Every tile in the legend has a name and a plain language description.
    for (final entry in kTileLegend) {
      expect(
        find.text(entry.name),
        findsOneWidget,
        reason: 'missing legend entry ${entry.name}',
      );
      expect(
        find.text(entry.description),
        findsOneWidget,
        reason: 'missing description for ${entry.name}',
      );
    }

    // The tile miniatures really are drawn, one per legend row.
    expect(find.byType(TileSwatch), findsNWidgets(kTileLegend.length));

    // And the meta buttons are explained.
    expect(find.text('SECOND CHANCE'), findsWidgets);
    expect(find.text('TRY AGAIN'), findsWidgets);

    // Close returns to the menu.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HowToPlayScreen), findsNothing);
    expect(find.text('PLAY'), findsOneWidget);
  });

  testWidgets('the very first PLAY opens the tutorial, not the board', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('MOVE'), findsNothing);

    await tapPlay(tester);

    // Step 1 of the walkthrough is up, and the world is frozen behind it.
    expect(tutorialText('MOVE'), findsOneWidget);
    expect(tutorialText('Every move advances one turn.'), findsOneWidget);
    expect(tutorialText('STEP 1 / ${kTutorialSteps.length}'), findsOneWidget);
    expect(tutorialText('SKIP'), findsOneWidget);
    expect(tutorialText('NEXT'), findsOneWidget);

    // The board is visible but cannot be played yet.
    expect(find.text('EXIT IN'), findsOneWidget);
  });

  testWidgets('every tutorial card can be stepped through with NEXT', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapPlay(tester);

    for (var i = 0; i < kTutorialSteps.length; i++) {
      final step = kTutorialSteps[i];
      expect(tutorialText(step.title), findsOneWidget);
      expect(tutorialText(step.body), findsOneWidget);

      final isLast = i == kTutorialSteps.length - 1;
      expect(tutorialText(isLast ? 'START' : 'NEXT'), findsOneWidget);

      await tester.tap(tutorialText(isLast ? 'START' : 'NEXT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    // Closing the walkthrough hands over to the live board.
    expect(tutorialText('MOVE'), findsNothing);
    expect(tutorialText('NEXT'), findsNothing);
    expect(find.text('LEVEL 1'), findsOneWidget);
    expect(find.text('EXIT IN'), findsOneWidget);
  });

  testWidgets('finishing the tutorial is remembered', (tester) async {
    await pumpApp(tester);
    expect(await tutorialSeenOnDisk(), isFalse);

    await tapPlay(tester);
    await completeTutorial(tester);

    expect(await tutorialSeenOnDisk(), isTrue);
  });

  testWidgets('SKIP also remembers that the tutorial was shown', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapPlay(tester);
    expect(tutorialText('MOVE'), findsOneWidget);

    await tester.tap(tutorialText('SKIP'));
    await tester.pump();

    expect(tutorialText('MOVE'), findsNothing);
    expect(await tutorialSeenOnDisk(), isTrue);
    expect(find.text('EXIT IN'), findsOneWidget);
  });

  testWidgets('a second PLAY goes straight to the board', (tester) async {
    await pumpApp(tester);
    await tapPlay(tester);
    await completeTutorial(tester);
    expect(await tutorialSeenOnDisk(), isTrue);

    // Fresh launch, same device: the tutorial must not come back.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpApp(tester);

    await tapPlay(tester);

    expect(tutorialText('MOVE'), findsNothing);
    expect(tutorialText('NEXT'), findsNothing);
    expect(find.text('EXIT IN'), findsOneWidget);
  });

  testWidgets('the rules stay reachable after the tutorial was seen', (
    tester,
  ) async {
    await pumpApp(tester);
    await tapPlay(tester);
    await completeTutorial(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await pumpApp(tester);

    // The button is still there, and still works.
    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(HowToPlayScreen), findsOneWidget);
    expect(find.text('EXIT'), findsOneWidget);
  });

  testWidgets('teaching screens fit a small phone without overflowing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    // HOW TO PLAY on a small screen.
    await tester.tap(find.text('HOW TO PLAY'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('MOVING BLOCK'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // And the tutorial, all five cards.
    await tapPlay(tester);
    for (var i = 0; i < kTutorialSteps.length; i++) {
      final isLast = i == kTutorialSteps.length - 1;
      expect(tutorialText(isLast ? 'START' : 'NEXT'), findsOneWidget);
      await tester.tap(tutorialText(isLast ? 'START' : 'NEXT'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    }

    // A RenderFlex overflow anywhere would already have failed the test.
    expect(find.text('EXIT IN'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
