import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:last_move/game/models/game_status.dart';
import 'package:last_move/game/models/player_action.dart';
import 'package:last_move/ui/screens/game_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/game_test_helpers.dart';
import 'helpers/ui_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('shows the main menu with the best run panel', (tester) async {
    await pumpApp(tester);

    expect(find.text('LAST MOVE'), findsOneWidget);
    expect(find.text('PLAY'), findsOneWidget);
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(
      find.textContaining('Every move changes what comes next.'),
      findsOneWidget,
    );
    expect(find.text('BEST SCORE'), findsOneWidget);
    expect(find.text('BEST LEVEL'), findsOneWidget);
  });

  testWidgets('PLAY opens the arena with HUD, preview and controls', (
    tester,
  ) async {
    await pumpApp(tester);

    // A brand new player is taught first, then handed the board.
    await tapPlay(tester);
    await completeTutorial(tester);

    expect(find.text('SCORE'), findsOneWidget);
    expect(find.text('LEVEL'), findsOneWidget);
    expect(find.text('EXIT IN'), findsOneWidget);
    expect(find.text('BEST'), findsOneWidget);
    expect(find.text('NEXT'), findsOneWidget);
    expect(find.text('WAIT'), findsOneWidget);
    // The level intro call-out is up after the tutorial closes.
    expect(find.text('LEVEL 1'), findsOneWidget);

    // The touch controls really drive the game.
    await tester.tap(find.byIcon(Icons.keyboard_arrow_up_rounded));
    await tester.pump();
    expect(find.text('10'), findsOneWidget);

    // Tear the game down so no animation tickers are left running.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('clearing a level shows LEVEL COMPLETE and then LEVEL 2', (
    tester,
  ) async {
    final controller = newController(seed: 8);
    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Take the level's last move.
    expect(unlockExitNextToPlayer(controller.state), isTrue);
    controller.perform(
      actionTowards(controller.state.player, controller.state.exitPosition!),
    );
    await tester.pump();

    expect(find.text('LEVEL COMPLETE'), findsOneWidget);
    expect(controller.status, GameStatus.levelComplete);

    // Input is locked while the transition plays.
    expect(controller.perform(PlayerAction.wait), isFalse);

    controller.advanceToNextLevel();
    await tester.pump();

    expect(find.text('LEVEL COMPLETE'), findsNothing);
    expect(find.text('LEVEL 2'), findsOneWidget);
    expect(controller.currentLevel, 2);
    expect(controller.status, GameStatus.playing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  testWidgets('a lethal turn opens the GAME OVER overlay with the level', (
    tester,
  ) async {
    final controller = newController(seed: 7);

    await tester.pumpWidget(
      MaterialApp(home: GameScreen(controller: controller)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    killCurrentRun(controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('GAME OVER'), findsOneWidget);
    expect(find.text('LEVEL REACHED'), findsOneWidget);
    expect(find.text('BEST LEVEL'), findsOneWidget);
    expect(find.text('BEST SCORE'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
    expect(find.text('MAIN MENU'), findsOneWidget);
    // One turn of history exists, so a (short) rewind is offered.
    expect(find.text('SECOND CHANCE'), findsOneWidget);

    // Second Chance closes the panel and resumes the same level.
    await tester.tap(find.text('SECOND CHANCE'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('GAME OVER'), findsNothing);
    expect(controller.status, GameStatus.playing);
    expect(controller.currentLevel, 1);

    // Die again and leave through TRY AGAIN this time.
    killCurrentRun(controller);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('GAME OVER'), findsOneWidget);

    await tester.tap(find.text('TRY AGAIN'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('GAME OVER'), findsNothing);
    expect(controller.currentLevel, 1);
    expect(controller.score, 0);
    expect(controller.status, GameStatus.playing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    controller.dispose();
  });

  group('layout', () {
    Future<void> pumpAt(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    testWidgets('the HUD and controls fit a small phone without overflowing', (
      tester,
    ) async {
      await pumpAt(tester, const Size(320, 568));
      final controller = newController(seed: 11);

      await tester.pumpWidget(
        MaterialApp(home: GameScreen(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // A RenderFlex overflow anywhere would already have failed the test.
      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('LEVEL'), findsOneWidget);
      expect(find.text('EXIT IN'), findsOneWidget);
      expect(find.text('WAIT'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('a wide desktop window keeps the arena on screen', (
      tester,
    ) async {
      await pumpAt(tester, const Size(1600, 900));
      final controller = newController(seed: 12);

      await tester.pumpWidget(
        MaterialApp(home: GameScreen(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('SCORE'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    });

    testWidgets('the game over panel fits a small phone', (tester) async {
      await pumpAt(tester, const Size(320, 568));
      final controller = newController(seed: 13);

      await tester.pumpWidget(
        MaterialApp(home: GameScreen(controller: controller)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      killCurrentRun(controller);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('GAME OVER'), findsOneWidget);
      expect(find.text('LEVEL REACHED'), findsOneWidget);
      expect(find.text('BEST LEVEL'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      controller.dispose();
    });
  });
}
