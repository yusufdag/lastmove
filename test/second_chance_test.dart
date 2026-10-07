import 'package:flutter_test/flutter_test.dart';
import 'package:last_move/game/models/game_state.dart';
import 'package:last_move/game/models/game_status.dart';
import 'package:last_move/game/models/hazard.dart';
import 'package:last_move/game/models/player_action.dart';
import 'package:last_move/game/systems/future_preview_system.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/game_test_helpers.dart';

void main() {
  const previewSystem = FuturePreviewSystem();

  group('GameSnapshot', () {
    test('restores the exact world, including the random stream', () {
      final state = newState(99);
      // A few real moves so the player, hazards and walls have all changed.
      for (final action in <PlayerAction>[
        PlayerAction.right,
        PlayerAction.right,
        PlayerAction.down,
        PlayerAction.left,
        PlayerAction.wait,
      ]) {
        kTurns.advance(state, action);
      }

      final restored = GameState.fromSnapshot(state.toSnapshot());

      expect(restored.turn, state.turn);
      expect(restored.score, state.score);
      expect(restored.player, state.player);
      expect(restored.status, state.status);
      expect(restored.shrinkLevel, state.shrinkLevel);
      expect(restored.blocks, equals(state.blocks));
      expect(restored.movingBlocks, equals(state.movingBlocks));
      expect(restored.hazards, equals(state.hazards));
      expect(restored.rng.state, state.rng.state);

      // Both worlds must keep evolving identically, which proves the snapshot
      // captured everything the generator depends on.
      final original = state.copy();
      final copy = restored.copy();
      for (var i = 0; i < 10; i++) {
        kTurns.advance(original, PlayerAction.wait);
        kTurns.advance(copy, PlayerAction.wait);
      }

      expect(copy.turn, original.turn);
      expect(copy.player, original.player);
      expect(copy.status, original.status);
      expect(copy.hazards, equals(original.hazards));
    });

    test('carries the level, the exit and the run totals', () {
      final state = newState(108, level: 5);
      state.config = state.config.copyWith(spawnChance: 0, movingBlockCount: 0);
      state.score = 1234;
      state.turn = 40;

      final before = GameState.fromSnapshot(state.toSnapshot());
      expect(before.currentLevel, 5);
      expect(before.levelTurn, state.levelTurn);
      expect(before.score, 1234);
      expect(before.turn, 40);
      expect(before.exitUnlocked, isFalse);
      expect(before.exitPosition, isNull);
      expect(before.requiredSurvivalTurns, state.requiredSurvivalTurns);
      expect(before.config.modifier, state.config.modifier);
      expect(before.config.columns, state.config.columns);

      // Now let the exit open and snapshot again.
      for (var i = 0; i < 3; i++) {
        kTurns.advance(state, PlayerAction.wait);
      }
      state.levelTurn = state.requiredSurvivalTurns - 1;
      kTurns.advance(state, PlayerAction.wait);
      expect(state.exitUnlocked, isTrue);

      final opened = GameState.fromSnapshot(state.toSnapshot());
      expect(opened.currentLevel, 5);
      expect(opened.exitUnlocked, isTrue);
      expect(opened.exitPosition, state.exitPosition);
      expect(opened.turnsUntilExit, 0);

      // And the restored world keeps evolving identically.
      final a = state.copy();
      final b = opened.copy();
      for (var i = 0; i < 6; i++) {
        kTurns.advance(a, PlayerAction.wait);
        kTurns.advance(b, PlayerAction.wait);
      }
      expect(b.currentLevel, a.currentLevel);
      expect(b.levelTurn, a.levelTurn);
      expect(b.exitUnlocked, a.exitUnlocked);
      expect(b.exitPosition, a.exitPosition);
      expect(b.hazards, equals(a.hazards));
      expect(b.status, a.status);
    });
  });

  group('FuturePreviewSystem', () {
    test('describes the next three turns without touching the real game', () {
      final state = newState(123);
      final before = state.toSnapshot();

      final preview = previewSystem.analyze(state, kTurns);

      expect(preview.length, 3);
      expect(preview[0].turnsAhead, 1);
      expect(preview[2].turnsAhead, 3);
      // The simulation runs on a clone, so the live game must be untouched.
      expect(state.turn, before.turn);
      expect(state.hazards, equals(before.hazards));
      expect(state.rng.state, before.rngState);
    });

    test('reports nothing once the run is over', () {
      final state = newState(124)..status = GameStatus.gameOver;
      expect(previewSystem.analyze(state, kTurns), isEmpty);
    });

    test('reports nothing during a level transition', () {
      final state = newState(125)..status = GameStatus.levelComplete;
      expect(previewSystem.analyze(state, kTurns), isEmpty);
    });
  });

  group('GameController second chance', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{});
    });

    test('rewinds three turns inside the level the player died on', () async {
      final controller = newController(seed: 204);
      addTearDown(controller.dispose);
      expect(runToLevel(controller, 3), isTrue);
      pacifyController(controller);

      final hazardHistory = <int, List<Hazard>>{};
      for (var i = 0; i < 5; i++) {
        controller.perform(PlayerAction.wait);
        hazardHistory[controller.turn] = List<Hazard>.of(
          controller.state.hazards,
        );
      }

      killCurrentRun(controller);

      expect(controller.status, GameStatus.gameOver);
      final deathTurn = controller.turn;
      final levelAtDeath = controller.currentLevel;
      expect(levelAtDeath, 3);
      expect(controller.canUseSecondChance, isTrue);

      final hazardsAtDeath = List<Hazard>.of(controller.state.hazards);
      final granted = await controller.requestSecondChance();

      expect(granted, isTrue);
      expect(controller.lastRewindTurns, 3);
      expect(controller.status, GameStatus.playing);

      // Same level, three turns earlier - not back to level 1.
      expect(controller.currentLevel, levelAtDeath);
      expect(controller.turn, deathTurn - 3);
      // Level 3 began after two cleared levels, so its own counter is three back.
      expect(controller.state.levelTurn, 3);

      // The whole board really is the one from three turns ago.
      expect(controller.state.hazards, equals(hazardHistory[deathTurn - 3]));
      expect(controller.state.hazards, isNot(equals(hazardsAtDeath)));
      expect(
        controller.state.dangerCells.contains(controller.state.player),
        isFalse,
      );

      // ...and the run keeps going normally afterwards.
      expect(controller.perform(PlayerAction.wait), isTrue);
      expect(controller.turn, deathTurn - 2);
    });

    test('does nothing while the player is still alive', () async {
      final controller = newController(seed: 205);
      addTearDown(controller.dispose);
      expect(await controller.requestSecondChance(), isFalse);
      expect(controller.status, GameStatus.playing);
    });

    test('an exit that is already open survives the rewind', () async {
      final controller = newController(seed: 206);
      addTearDown(controller.dispose);
      expect(runToLevel(controller, 2), isTrue);
      pacifyController(controller);

      for (var i = 0; i < 4; i++) {
        controller.perform(PlayerAction.wait);
      }
      controller.state.levelTurn = controller.requiredSurvivalTurns - 1;
      controller.perform(PlayerAction.wait);
      expect(controller.exitUnlocked, isTrue);
      final exitCell = controller.exitPosition;

      for (var i = 0; i < 6; i++) {
        controller.perform(PlayerAction.wait);
      }
      killCurrentRun(controller);
      expect(controller.status, GameStatus.gameOver);

      final turnAtDeath = controller.turn;
      expect(await controller.requestSecondChance(), isTrue);

      expect(controller.currentLevel, 2);
      expect(controller.turn, turnAtDeath - 3);
      expect(controller.exitUnlocked, isTrue);
      expect(controller.exitPosition, exitCell);
    });

    test('rewinding to before the exit opened restores it as closed', () async {
      final controller = newController(seed: 207);
      addTearDown(controller.dispose);
      pacifyController(controller);

      for (var i = 0; i < 4; i++) {
        controller.perform(PlayerAction.wait);
      }
      controller.state.levelTurn = controller.requiredSurvivalTurns - 1;
      controller.perform(PlayerAction.wait);
      expect(controller.exitUnlocked, isTrue);

      controller.perform(PlayerAction.wait);
      killCurrentRun(controller);
      expect(controller.status, GameStatus.gameOver);

      expect(await controller.requestSecondChance(), isTrue);

      expect(controller.currentLevel, 1);
      expect(controller.exitUnlocked, isFalse);
      expect(controller.exitPosition, isNull);
      expect(controller.turnsUntilExit, greaterThan(0));
    });
  });
}
