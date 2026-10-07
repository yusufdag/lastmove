import 'package:flutter_test/flutter_test.dart';
import 'package:last_move/game/game_controller.dart';
import 'package:last_move/game/models/game_rules.dart';
import 'package:last_move/game/models/game_status.dart';
import 'package:last_move/game/models/hazard.dart';
import 'package:last_move/game/models/player_action.dart';
import 'package:last_move/game/services/score_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/game_test_helpers.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  /// Makes the current level hazard free so a test can spend turns without the
  /// generator deciding the outcome for it.
  void pacify(GameController controller) {
    controller.state.config = controller.state.config.copyWith(
      spawnChance: 0,
      movingBlockCount: 0,
      shrinkEnabled: false,
      maxShrinkLevel: 0,
    );
  }

  /// Plants an unavoidable lethal cell under the player and spends the turn, so
  /// the run ends on a known level.
  void killRun(GameController controller) {
    final state = controller.state;
    state.hazards.add(
      Hazard(
        id: 99999,
        position: state.player,
        warningFromTurn: 0,
        dangerFromTurn: 0,
        dangerUntilTurn: 9999,
      ),
    );
    state.refreshDerived();
    controller.perform(PlayerAction.wait);
  }

  group('run flow', () {
    test('a new run starts on level 1 with score 0 and the exit locked', () {
      final controller = newController(seed: 101);
      addTearDown(controller.dispose);

      expect(controller.currentLevel, 1);
      expect(controller.levelReached, 1);
      expect(controller.score, 0);
      expect(controller.turn, 0);
      expect(controller.levelTurn, 0);
      expect(controller.status, GameStatus.playing);
      expect(controller.exitUnlocked, isFalse);
      expect(controller.exitPosition, isNull);
      expect(controller.requiredSurvivalTurns, 8);
      expect(controller.turnsUntilExit, 8);
      expect(controller.levelConfig.level, 1);
      expect(controller.banner?.title, 'LEVEL 1');
    });

    test('the exit opens on the turn the survival requirement is met', () {
      final controller = newController(seed: 102);
      addTearDown(controller.dispose);
      pacify(controller);
      controller.state.hazards.clear();

      controller.state.levelTurn = controller.requiredSurvivalTurns - 1;
      expect(controller.turnsUntilExit, 1);

      controller.perform(PlayerAction.wait);

      expect(controller.exitUnlocked, isTrue);
      expect(controller.exitPosition, isNotNull);
      expect(controller.turnsUntilExit, 0);
      expect(controller.banner?.title, 'LAST MOVE!');
    });

    test('reaching the exit clears the level and keeps the run going', () {
      final controller = newController(seed: 103);
      addTearDown(controller.dispose);
      final levelTwo = kLevels.configFor(2);

      expect(clearCurrentLevel(controller), isTrue);

      expect(controller.currentLevel, 2);
      expect(controller.status, GameStatus.playing);
      expect(controller.levelTurn, 0);
      expect(controller.exitUnlocked, isFalse);
      expect(controller.exitPosition, isNull);
      expect(controller.levelConfig.level, 2);
      expect(controller.requiredSurvivalTurns, levelTwo.requiredSurvivalTurns);
      expect(controller.columns, levelTwo.columns);

      // The previous level is wiped: no hazards, no sliding walls, no shrink.
      expect(controller.state.hazards, isEmpty);
      expect(controller.state.movingBlocks, isEmpty);
      expect(controller.state.shrinkLevel, 0);
      expect(
        controller.state.blocks.length,
        lessThanOrEqualTo(levelTwo.blockCount),
      );

      // Score and total turns carry over.
      expect(controller.turn, 1);
      expect(
        controller.score,
        GameRules.scorePerTurn + GameRules.scorePerLevel,
      );
      expect(controller.banner?.title, 'LEVEL 2');
    });

    test('the completion bonus scales with the level number', () {
      final controller = newController(seed: 104);
      addTearDown(controller.dispose);

      expect(runToLevel(controller, 4), isTrue);

      var expected = 0;
      for (var level = 1; level <= 3; level++) {
        expected += GameRules.scorePerTurn + GameRules.scorePerLevel * level;
      }
      expect(controller.score, expected);
      expect(controller.turn, 3);
    });

    test('every level in a run asks for something harder', () {
      final controller = newController(seed: 105);
      addTearDown(controller.dispose);

      expect(runToLevel(controller, 8), isTrue);

      expect(controller.currentLevel, 8);
      expect(controller.levelConfig.level, 8);
      expect(
        controller.levelConfig.requiredSurvivalTurns,
        greaterThan(kLevels.configFor(1).requiredSurvivalTurns),
      );
      expect(controller.status, GameStatus.playing);
    });

    test('a dozen levels in a row run without the generator breaking', () {
      final controller = newController(seed: 106);
      addTearDown(controller.dispose);

      expect(runToLevel(controller, 13), isTrue);
      expect(controller.currentLevel, 13);
      expect(controller.score, greaterThan(0));
      expect(controller.status, GameStatus.playing);
    });

    test('TRY AGAIN resets the run to level 1 and score 0', () {
      final controller = newController(seed: 107);
      addTearDown(controller.dispose);
      expect(runToLevel(controller, 4), isTrue);

      controller.startNewGame();

      expect(controller.currentLevel, 1);
      expect(controller.score, 0);
      expect(controller.turn, 0);
      expect(controller.levelTurn, 0);
      expect(controller.exitUnlocked, isFalse);
      expect(controller.state.hazards, isEmpty);
      expect(controller.state.movingBlocks, isEmpty);
      expect(controller.state.shrinkLevel, 0);
      expect(controller.canUseSecondChance, isFalse);
      expect(controller.banner?.title, 'LEVEL 1');
    });

    test(
      'death reports the level reached and stores best score and level',
      () async {
        final controller = newController(seed: 108);
        addTearDown(controller.dispose);
        expect(runToLevel(controller, 3), isTrue);
        pacify(controller);

        killRun(controller);
        // Dying still scores the turn it happened on.
        final scoreAtDeath = controller.score;

        expect(controller.status, GameStatus.gameOver);
        expect(controller.levelReached, 3);
        expect(controller.bestLevel, 3);
        expect(controller.bestScore, scoreAtDeath);

        // The very next run starts from scratch but keeps the records.
        controller.startNewGame();
        expect(controller.currentLevel, 1);
        expect(controller.score, 0);
        expect(controller.bestLevel, 3);
        expect(controller.bestScore, scoreAtDeath);

        // And they are on disk too.
        await Future<void>.delayed(Duration.zero);
        final stored = ScoreService();
        await stored.loadBest();
        expect(stored.cachedBestLevel, 3);
        expect(stored.cachedBestScore, scoreAtDeath);
      },
    );

    test('the future preview keeps working across a level change', () {
      final controller = newController(seed: 109);
      addTearDown(controller.dispose);

      expect(controller.preview.length, GameRules.previewTurns);
      expect(clearCurrentLevel(controller), isTrue);
      expect(controller.preview.length, GameRules.previewTurns);
    });

    test('a brand new player is nudged once, a returning one never', () {
      bool sawWarningHint(GameController controller) {
        var seen = false;
        var guard = 0;
        while (controller.status.isRunning && guard < 60) {
          guard++;
          controller.perform(PlayerAction.wait);
          if (controller.banner?.kind == LevelBannerKind.warningHint) {
            seen = true;
          }
        }
        return seen;
      }

      // First run: never seen the tutorial, so the warning is explained once.
      final rookie = newController(seed: 112);
      addTearDown(rookie.dispose);
      expect(rookie.hasSeenTutorial, isFalse);
      rookie.startNewGame();
      expect(sawWarningHint(rookie), isTrue);

      // Returning player: skipping the tutorial is enough to count as taught.
      final veteran = newController(seed: 112);
      addTearDown(veteran.dispose);
      veteran.startTutorial();
      veteran.skipTutorial();
      expect(veteran.hasSeenTutorial, isTrue);
      veteran.startNewGame();
      expect(sawWarningHint(veteran), isFalse);
    });

    test('a worse run never lowers the stored best level', () async {
      final controller = newController(seed: 110);
      addTearDown(controller.dispose);

      expect(runToLevel(controller, 5), isTrue);
      pacify(controller);
      killRun(controller);
      expect(controller.bestLevel, 5);
      await Future<void>.delayed(Duration.zero);

      controller.startNewGame();
      expect(runToLevel(controller, 3), isTrue);
      pacify(controller);
      killRun(controller);

      expect(controller.bestLevel, 5);
      expect(controller.lastRunWasPersonalBest, isFalse);
      expect(controller.levelReached, 3);
    });
  });

  group('balance', () {
    test('a cautious player comfortably clears the opening levels', () {
      var reachedThree = 0;
      var reachedFive = 0;
      var reachedEight = 0;
      var reachedTwelve = 0;
      var reachedTwenty = 0;
      const runs = 20;

      for (var seed = 1; seed <= runs; seed++) {
        final controller = newController(seed: seed);
        final levels = _playCautiously(controller, maxTurns: 600);
        if (levels >= 3) {
          reachedThree++;
        }
        if (levels >= 5) {
          reachedFive++;
        }
        if (levels >= 8) {
          reachedEight++;
        }
        if (levels >= 12) {
          reachedTwelve++;
        }
        if (levels >= 20) {
          reachedTwenty++;
        }
        controller.dispose();
      }

      // A new player is meant to see the first three levels without much trouble,
      // and someone with the hang of it should push well past five. The thresholds
      // sit below what a one turn lookahead actually reaches, so the curve can
      // still be re-tuned later without rewriting the test.
      final hits =
          '$reachedThree/$reachedFive/$reachedEight/$reachedTwelve/'
          '$reachedTwenty out of $runs';
      expect(reachedThree, greaterThanOrEqualTo(18), reason: hits);
      expect(reachedFive, greaterThanOrEqualTo(14), reason: hits);
      expect(reachedEight, greaterThanOrEqualTo(12), reason: hits);
      expect(reachedTwelve, greaterThanOrEqualTo(6), reason: hits);
    });

    test('nobody dies before they get a turn to react', () {
      for (var seed = 1; seed <= 30; seed++) {
        final controller = newController(seed: seed);
        for (var i = 0; i < 3; i++) {
          controller.perform(PlayerAction.wait);
        }
        expect(
          controller.status,
          GameStatus.playing,
          reason: 'seed $seed died within the grace turns',
        );
        controller.dispose();
      }
    });
  });
}

/// Plays like a careful human would: never step onto a cell that is lethal once
/// the turn resolves, prefer cells that are not telegraphed, keep escape routes
/// open and head for the exit once it is up.
///
/// It is a one turn lookahead, so it is a reasonable stand-in for a competent
/// player and a fair way to measure the difficulty curve.
int _playCautiously(GameController controller, {required int maxTurns}) {
  var turns = 0;
  while (controller.status.isRunning && turns < maxTurns) {
    turns++;
    controller.perform(_safestAction(controller));
    if (controller.status.isLevelComplete) {
      controller.advanceToNextLevel();
    }
  }
  return controller.currentLevel;
}

PlayerAction _safestAction(GameController controller) {
  final state = controller.state;
  final exit = state.exitUnlocked ? state.exitPosition : null;

  // The level's last move is worth taking the moment it is available.
  if (exit != null && state.player.manhattanDistanceTo(exit) == 1) {
    return actionTowards(state.player, exit);
  }

  var best = PlayerAction.wait;
  var bestScore = double.negativeInfinity;

  for (final action in PlayerAction.values) {
    final clone = state.copy();
    final event = kTurns.advance(clone, action);
    if (!event.accepted || event.died) {
      continue;
    }

    var score = 0.0;
    if (!clone.dangerCells.contains(clone.player)) {
      score += 2;
    }
    if (!clone.warningCells.contains(clone.player)) {
      score += 3;
    }
    if (state.warningCells.contains(clone.player)) {
      // Stepping into a live warning is a bad habit to teach the simulation.
      score -= 4;
    }

    if (exit != null) {
      final before = state.player.manhattanDistanceTo(exit);
      final after = clone.player.manhattanDistanceTo(exit);
      score += (before - after) * 1.5;
    }

    var escapes = 0;
    for (final neighbour in clone.neighborsOf(clone.player)) {
      if (clone.isObstacle(neighbour) ||
          clone.dangerCells.contains(neighbour)) {
        continue;
      }
      escapes++;
    }
    score += escapes * 0.5;

    if (score > bestScore) {
      bestScore = score;
      best = action;
    }
  }

  return best;
}
