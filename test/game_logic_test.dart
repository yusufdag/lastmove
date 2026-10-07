import 'package:flutter_test/flutter_test.dart';
import 'package:last_move/game/models/game_rules.dart';
import 'package:last_move/game/models/game_state.dart';
import 'package:last_move/game/models/game_status.dart';
import 'package:last_move/game/models/hazard.dart';
import 'package:last_move/game/models/level_config.dart';
import 'package:last_move/game/models/moving_block.dart';
import 'package:last_move/game/models/player_action.dart';
import 'package:last_move/game/models/tile_position.dart';
import 'package:last_move/game/models/turn_event.dart';
import 'package:last_move/game/systems/hazard_system.dart';
import 'package:last_move/game/systems/history_system.dart';
import 'package:last_move/game/systems/level_system.dart';

import 'helpers/game_test_helpers.dart';

void main() {
  const hazardSystem = HazardSystem();

  group('GameState', () {
    test('level 1 spawns the player in the middle with the exit locked', () {
      final state = newState(1);
      expect(state.currentLevel, 1);
      expect(state.turn, 0);
      expect(state.levelTurn, 0);
      expect(state.score, 0);
      expect(state.status, GameStatus.playing);
      expect(state.player, const TilePosition(4, 4));
      expect(state.columns, 8);
      expect(state.rows, 8);
      expect(state.exitUnlocked, isFalse);
      expect(state.exitPosition, isNull);
      expect(state.blocks, isEmpty);
    });

    test('keeps the spawn ring clear of walls', () {
      for (var seed = 1; seed <= 30; seed++) {
        final state = newState(seed, level: 12);
        expect(state.blocks.contains(state.player), isFalse);
        for (final neighbour in state.neighborsOf(state.player)) {
          expect(
            state.blocks.contains(neighbour),
            isFalse,
            reason: 'seed $seed blocked the spawn ring',
          );
        }
      }
    });

    test('walls never seal the player into a pocket', () {
      for (var seed = 1; seed <= 60; seed++) {
        final state = newState(seed, level: 20);
        final freeCells = state.cellCount - state.blocks.length;
        expect(
          state.reachableCells().length * 2 >= freeCells,
          isTrue,
          reason: 'seed $seed left the player boxed in',
        );
      }
    });

    test('ringIndexOf reports the distance to the closest edge', () {
      final state = newState(1);
      expect(state.ringIndexOf(const TilePosition(0, 3)), 0);
      expect(state.ringIndexOf(const TilePosition(1, 1)), 1);
      expect(state.ringIndexOf(const TilePosition(2, 4)), 2);
      expect(state.ringIndexOf(const TilePosition(3, 3)), 3);
    });

    test('supports other arena sizes through the config', () {
      final state = newState(2, columns: 10, rows: 6);
      expect(state.player, const TilePosition(5, 3));
      expect(state.contains(const TilePosition(9, 5)), isTrue);
      expect(state.contains(const TilePosition(10, 5)), isFalse);
    });

    test('shrinkLevelAt grows, stops at the cap and respects the schedule', () {
      final state = newState(3, level: 7);
      final config = state.config;
      expect(config.hasShrink, isTrue);

      expect(state.shrinkLevelAt(0), 0);
      expect(state.shrinkLevelAt(config.shrinkStartTurn), 1);
      expect(
        state.shrinkLevelAt(config.shrinkStartTurn + config.shrinkInterval),
        2,
      );
      expect(state.shrinkLevelAt(999), config.maxShrinkLevel);
    });

    test('a level without shrink never becomes lethal at the edges', () {
      final state = newState(4, level: 2);
      expect(state.config.hasShrink, isFalse);
      expect(state.shrinkLevelAt(50), 0);
      expect(state.isShrinkLethal(const TilePosition(0, 0)), isFalse);
    });
  });

  group('TurnSystem', () {
    test('moves the player and advances turn and level turn', () {
      final state = newState(20);
      final start = state.player;

      final event = kTurns.advance(state, PlayerAction.right);

      expect(event.accepted, isTrue);
      expect(event.died, isFalse);
      expect(state.turn, 1);
      expect(state.levelTurn, 1);
      expect(state.player, start + const TilePosition(1, 0));
      expect(state.score, 10);
      expect(state.recentMoves.first, PlayerAction.right);
    });

    test('a wall costs nothing: the turn is not spent', () {
      final state = newState(20);
      state.blocks.add(const TilePosition(0, 0));
      state.player = const TilePosition(1, 0);

      final event = kTurns.advance(state, PlayerAction.left);

      expect(event.accepted, isFalse);
      expect(state.turn, 0);
      expect(state.levelTurn, 0);
      expect(state.score, 0);
      expect(state.player, const TilePosition(1, 0));
    });

    test('cannot leave the arena', () {
      final state = newState(20);
      state.player = const TilePosition(0, 0);

      expect(kTurns.advance(state, PlayerAction.up).accepted, isFalse);
      expect(state.player, const TilePosition(0, 0));
    });

    test('a warning becomes lethal two turns later, then clears', () {
      final state = newState(30);
      state.hazards.clear();
      state.hazards.add(
        const Hazard(
          id: 900,
          position: TilePosition(0, 0),
          warningFromTurn: 1,
          dangerFromTurn: 2,
          dangerUntilTurn: 3,
        ),
      );

      kTurns.advance(state, PlayerAction.wait);
      expect(state.turn, 1);
      expect(state.warningCells.contains(const TilePosition(0, 0)), isTrue);
      expect(state.dangerCells.contains(const TilePosition(0, 0)), isFalse);

      kTurns.advance(state, PlayerAction.wait);
      expect(state.turn, 2);
      expect(state.warningCells.contains(const TilePosition(0, 0)), isFalse);
      expect(state.dangerCells.contains(const TilePosition(0, 0)), isTrue);

      kTurns.advance(state, PlayerAction.wait);
      expect(state.turn, 3);
      expect(state.dangerCells.contains(const TilePosition(0, 0)), isFalse);
    });

    test('ending a turn on a lethal cell ends the run', () {
      final state = newState(40);
      state.hazards.clear();
      // Already lethal before the turn starts, so the fairness pass cannot
      // remove it either.
      state.hazards.add(
        Hazard(
          id: 901,
          position: state.player,
          warningFromTurn: 0,
          dangerFromTurn: 0,
          dangerUntilTurn: 99,
        ),
      );
      state.refreshDerived();

      final event = kTurns.advance(state, PlayerAction.wait);

      expect(event.died, isTrue);
      expect(state.status, GameStatus.gameOver);
      expect(state.turn, 1);
    });

    test('nothing happens while paused, over or mid transition', () {
      for (final status in <GameStatus>[
        GameStatus.paused,
        GameStatus.gameOver,
        GameStatus.levelComplete,
      ]) {
        final state = newState(50)..status = status;
        expect(kTurns.advance(state, PlayerAction.wait).accepted, isFalse);
        expect(state.turn, 0);
      }
    });

    test('the opening turns are quiet for every seed', () {
      for (var seed = 1; seed <= 40; seed++) {
        final state = newState(seed);
        for (var i = 0; i < LevelSystem.graceTurns; i++) {
          kTurns.advance(state, PlayerAction.wait);
        }
        expect(
          state.status,
          GameStatus.playing,
          reason: 'seed $seed died inside the grace period',
        );
        expect(state.turn, LevelSystem.graceTurns);
      }
    });

    test('waiting forever still ends the run on a hard level', () {
      for (var seed = 1; seed <= 5; seed++) {
        final state = newState(seed, level: 25);
        var guard = 0;
        while (state.status.isRunning && guard < 300) {
          guard++;
          kTurns.advance(state, PlayerAction.wait);
        }
        expect(
          state.status,
          GameStatus.gameOver,
          reason: 'seed $seed survived 300 idle turns at level 25',
        );
        expect(state.score, state.turn * 10);
      }
    });
  });

  group('Exit flow', () {
    test('the exit opens exactly when the survival requirement is met', () {
      final state = newState(60);
      // A hazard free level keeps this deterministic: the point is the timing of
      // the exit, not surviving it.
      state.config = state.config.copyWith(spawnChance: 0, movingBlockCount: 0);
      final required = state.requiredSurvivalTurns;
      expect(required, 8);

      for (var i = 0; i < required - 1; i++) {
        kTurns.advance(state, PlayerAction.wait);
      }
      expect(state.exitUnlocked, isFalse);
      expect(state.turnsUntilExit, 1);

      final event = kTurns.advance(state, PlayerAction.wait);

      expect(event.exitOpened, isTrue);
      expect(state.exitUnlocked, isTrue);
      expect(state.exitPosition, isNotNull);
      expect(state.turnsUntilExit, 0);
    });

    test('walking into the exit is the last move that clears the level', () {
      final state = newState(61);
      state.config = state.config.copyWith(spawnChance: 0, movingBlockCount: 0);
      for (var i = 0; i < state.requiredSurvivalTurns; i++) {
        kTurns.advance(state, PlayerAction.wait);
      }
      final exit = state.exitPosition!;
      expect(state.exitUnlocked, isTrue);

      final hazardsBefore = List<Hazard>.of(state.hazards);
      var guard = 0;
      var event = _stepOnceTowards(state, exit);
      while (event != null &&
          !event.levelCompleted &&
          state.status.isRunning &&
          guard < 100) {
        guard++;
        event = _stepOnceTowards(state, exit);
      }

      expect(state.status, GameStatus.levelComplete);
      expect(event?.levelCompleted, isTrue);
      expect(state.player, exit);
      expect(event?.levelBonus, GameRules.scorePerLevel);
      expect(
        state.score,
        state.turn * GameRules.scorePerTurn + GameRules.scorePerLevel,
      );
      // Completing the level does not resolve a world turn, so nothing new can
      // hit the player on the way out.
      expect(state.hazards, equals(hazardsBefore));
    });

    test('the exit is always placed on reachable, safe ground', () {
      for (var seed = 1; seed <= 40; seed++) {
        final state = newState(seed, level: 7);
        state.config = state.config.copyWith(
          spawnChance: 0,
          movingBlockCount: 0,
        );
        for (var i = 0; i < state.requiredSurvivalTurns; i++) {
          kTurns.advance(state, PlayerAction.wait);
        }

        expect(
          state.exitUnlocked,
          isTrue,
          reason: 'seed $seed never opened the exit',
        );
        final exit = state.exitPosition!;
        expect(state.dangerCells.contains(exit), isFalse);
        expect(state.isObstacle(exit), isFalse);
        expect(state.ringIndexOf(exit) >= state.config.safeRingFloor, isTrue);
        expect(
          state.canReach(exit, avoidHazards: true),
          isTrue,
          reason: 'seed $seed opened an unreachable exit',
        );
      }
    });

    test('the exit is never telegraphed, blocked or crushed mid level', () {
      for (var seed = 1; seed <= 25; seed++) {
        final state = newState(seed, level: 10);
        // Fast forward to the turn the exit opens on.
        state.levelTurn = state.requiredSurvivalTurns - 1;
        kTurns.advance(state, PlayerAction.wait);
        expect(state.exitUnlocked, isTrue);
        final exit = state.exitPosition!;

        var guard = 0;
        while (state.status.isRunning && guard < 25) {
          guard++;
          kTurns.advance(state, PlayerAction.wait);
          expect(state.warningCells.contains(exit), isFalse);
          expect(state.dangerCells.contains(exit), isFalse);
          expect(state.movingBlockAt(exit), isNull);
          expect(state.isObstacle(exit), isFalse);
        }
      }
    });

    test('the hazard generator never picks the exit cell', () {
      final state = newState(70, level: 15);
      state.exitUnlocked = true;
      state.exitPosition = const TilePosition(0, 0);
      state.hazards = <Hazard>[];
      const profile = DifficultyProfile(
        hazardsToSpawn: 4,
        telegraphTurns: 2,
        dangerDuration: 1,
        maxConcurrentHazards: 8,
        movingBlockTarget: 0,
      );

      for (var i = 0; i < 120; i++) {
        state.turn = 40 + i;
        state.hazards = <Hazard>[];
        state.refreshDerived();
        hazardSystem.spawnTelegraphs(state, turn: state.turn, profile: profile);
        for (final hazard in state.hazards) {
          expect(hazard.position, isNot(state.exitPosition));
        }
      }
    });
  });

  group('LevelSystem', () {
    test('level 1 is a real tutorial', () {
      final config = kLevels.configFor(1);
      expect(config.level, 1);
      expect(config.modifier, LevelModifier.normal);
      expect(config.columns, 8);
      expect(config.rows, 8);
      expect(config.requiredSurvivalTurns, 8);
      expect(config.blockCount, 0);
      expect(config.movingBlockCount, 0);
      expect(config.hasShrink, isFalse);
      expect(config.maxConcurrentHazards, 1);
      expect(config.telegraphTurns, 3);
      expect(config.maxSpawnsPerTurn, 1);
      expect(config.exitMinDistance, 2);
    });

    test('levels 2 and 3 stay easy but ask for more turns', () {
      final one = kLevels.configFor(1);
      final two = kLevels.configFor(2);
      final three = kLevels.configFor(3);

      expect(two.requiredSurvivalTurns, greaterThan(one.requiredSurvivalTurns));
      expect(
        three.requiredSurvivalTurns,
        greaterThan(two.requiredSurvivalTurns),
      );
      expect(two.hasShrink, isFalse);
      expect(three.hasShrink, isFalse);
      expect(two.movingBlockCount, 0);
      expect(three.movingBlockCount, 0);
      expect(three.difficultyScore, greaterThan(two.difficultyScore));
      expect(two.difficultyScore, greaterThan(one.difficultyScore));
    });

    test('the curve keeps climbing towards an endless endgame', () {
      final l1 = kLevels.configFor(1);
      final l6 = kLevels.configFor(6);
      final l12 = kLevels.configFor(12);
      final l20 = kLevels.configFor(20);
      final l40 = kLevels.configFor(40);

      expect(l6.difficultyScore, greaterThan(l1.difficultyScore));
      expect(l12.difficultyScore, greaterThan(l6.difficultyScore));
      expect(l20.difficultyScore, greaterThan(l12.difficultyScore));
      expect(l40.difficultyScore, greaterThan(l20.difficultyScore));

      // Moving walls really do show up once the player has learned the board.
      expect(l1.movingBlockCount, 0);
      expect(l6.movingBlockCount, greaterThan(0));
    });

    test('every parameter stays inside its safety cap', () {
      for (var level = 1; level <= 200; level++) {
        final config = kLevels.configFor(level);
        final reason = 'level $level';
        expect(config.columns, inInclusiveRange(7, 9), reason: reason);
        expect(config.rows, config.columns, reason: reason);
        expect(
          config.requiredSurvivalTurns,
          inInclusiveRange(1, LevelSystem.maxSurvivalTurns),
          reason: reason,
        );
        expect(
          config.maxConcurrentHazards,
          inInclusiveRange(1, LevelSystem.maxConcurrentHazards),
          reason: reason,
        );
        expect(config.maxSpawnsPerTurn, inInclusiveRange(1, 3), reason: reason);
        expect(
          config.movingBlockCount,
          inInclusiveRange(0, LevelSystem.maxMovingBlocks),
          reason: reason,
        );
        expect(config.telegraphTurns, inInclusiveRange(1, 3), reason: reason);
        expect(config.dangerDuration, greaterThanOrEqualTo(1), reason: reason);
        expect(config.spawnChance, inInclusiveRange(0.0, 1.0), reason: reason);
        expect(
          config.blockCount,
          lessThanOrEqualTo(config.cellCount ~/ 7 + 1),
          reason: reason,
        );
        expect(
          config.exitMinDistance,
          inInclusiveRange(1, config.columns),
          reason: reason,
        );
        if (config.hasShrink) {
          expect(config.maxShrinkLevel, greaterThanOrEqualTo(1));
          expect(config.maxShrinkLevel, lessThan(config.columns ~/ 2));
          expect(config.shrinkInterval, greaterThan(0));
        }
      }
    });

    test('very high levels still generate a sane, playable world', () {
      for (final level in <int>[50, 100, 250, 1000]) {
        final config = kLevels.configFor(level);
        expect(config.level, level);
        expect(config.columns, inInclusiveRange(7, 9));

        // And the generator is happy to build a board with it.
        final state = newState(level, level: level);
        expect(state.currentLevel, level);
        expect(state.player, TilePosition(state.columns ~/ 2, state.rows ~/ 2));
        expect(state.blocks.isEmpty, isFalse);
      }
    });

    test('the level number alone decides the config', () {
      for (final level in <int>[1, 5, 13, 42]) {
        final a = kLevels.configFor(level);
        final b = kLevels.configFor(level);
        expect(a.difficultyScore, b.difficultyScore);
        expect(a.modifier, b.modifier);
        expect(a.requiredSurvivalTurns, b.requiredSurvivalTurns);
        expect(a.blockCount, b.blockCount);
        expect(a.exitMinDistance, b.exitMinDistance);
      }
      // Out of range numbers are clamped instead of exploding.
      expect(kLevels.configFor(0).level, 1);
      expect(kLevels.configFor(-5).level, 1);
    });

    test('levels are not all the same shape', () {
      final modifiers = <LevelModifier>{};
      final sizes = <int>{};
      for (var level = 4; level <= 40; level++) {
        final config = kLevels.configFor(level);
        modifiers.add(config.modifier);
        sizes.add(config.columns);
      }
      expect(modifiers.length, greaterThanOrEqualTo(4));
      expect(sizes, <int>{7, 8, 9});
    });

    test('the assist helpers track the survival requirement', () {
      final state = newState(90);
      expect(kLevels.turnsUntilExit(state), state.requiredSurvivalTurns);
      state.levelTurn = state.requiredSurvivalTurns;
      expect(kLevels.turnsUntilExit(state), 0);
      state.exitUnlocked = true;
      expect(kLevels.turnsUntilExit(state), 0);
      expect(kLevels.nextLevel(7), 8);
    });
  });

  group('HistorySystem', () {
    test('rewinds exactly the requested number of turns', () {
      final base = newState(60);
      final history = HistorySystem();
      history.reset(base.toSnapshot());

      for (var turn = 1; turn <= 6; turn++) {
        base.turn = turn;
        history.push(base.toSnapshot());
      }

      expect(history.length, 7);
      expect(history.rewindDepth(3), 3);

      final restored = history.rewind(3);
      expect(restored, isNotNull);
      expect(restored!.turn, 3);
      // The branch is truncated so the timeline cannot fork twice.
      expect(history.length, 4);
      expect(history.current?.turn, 3);
    });

    test('never rewinds further than the oldest frame', () {
      final base = newState(61);
      final history = HistorySystem(capacity: 3);
      history.reset(base.toSnapshot());

      for (var turn = 1; turn <= 5; turn++) {
        base.turn = turn;
        history.push(base.toSnapshot());
      }

      expect(history.length, 3);
      expect(history.rewindDepth(3), 2);
      expect(history.rewind(3)?.turn, 3);
    });

    test('cannot rewind a fresh session', () {
      final history = HistorySystem();
      history.reset(newState(62).toSnapshot());
      expect(history.canRewind, isFalse);
      expect(history.rewind(), isNull);
    });
  });

  group('HazardSystem', () {
    test('telegraphs land near the player far more often than chance', () {
      var near = 0;
      var total = 0;

      for (var seed = 1; seed <= 80; seed++) {
        final state = newState(seed, level: 3)
          ..turn = 10
          ..hazards = <Hazard>[]
          ..blocks = <TilePosition>[]
          ..movingBlocks = <MovingBlock>[];
        state.refreshDerived();

        hazardSystem.spawnTelegraphs(
          state,
          turn: 10,
          profile: const DifficultyProfile(
            hazardsToSpawn: 4,
            telegraphTurns: 2,
            dangerDuration: 1,
            maxConcurrentHazards: 8,
            movingBlockTarget: 0,
          ),
        );

        for (final hazard in state.hazards) {
          total++;
          if (hazard.position.manhattanDistanceTo(state.player) <= 2) {
            near++;
          }
        }
      }

      expect(total, greaterThan(200));
      // Uniform picking would put about 20% of the cells within distance two.
      expect(near / total, greaterThan(0.24));
    });

    test('drift direction shifts where telegraphs land', () {
      const profile = DifficultyProfile(
        hazardsToSpawn: 3,
        telegraphTurns: 2,
        dangerDuration: 1,
        maxConcurrentHazards: 6,
        movingBlockTarget: 0,
      );

      double averageX(List<PlayerAction> moves) {
        var sum = 0.0;
        var count = 0;
        for (var seed = 1; seed <= 60; seed++) {
          final state = newState(seed, level: 3)
            ..turn = 12
            ..hazards = <Hazard>[]
            ..blocks = <TilePosition>[]
            ..movingBlocks = <MovingBlock>[]
            ..recentMoves = List<PlayerAction>.of(moves);
          state.refreshDerived();
          hazardSystem.spawnTelegraphs(state, turn: 12, profile: profile);
          for (final hazard in state.hazards) {
            sum += hazard.position.x;
            count++;
          }
        }
        return sum / count;
      }

      final driftingRight = averageX(<PlayerAction>[
        PlayerAction.right,
        PlayerAction.right,
      ]);
      final driftingLeft = averageX(<PlayerAction>[
        PlayerAction.left,
        PlayerAction.left,
      ]);

      expect(driftingRight, greaterThan(driftingLeft));
    });

    test('never telegraphs a wall or stacks two on one cell', () {
      for (var seed = 1; seed <= 30; seed++) {
        final state = newState(seed, level: 12);
        state.refreshDerived();
        hazardSystem.spawnTelegraphs(
          state,
          turn: state.turn,
          profile: const DifficultyProfile(
            hazardsToSpawn: 3,
            telegraphTurns: 2,
            dangerDuration: 1,
            maxConcurrentHazards: 6,
            movingBlockTarget: 0,
          ),
        );

        final seen = <TilePosition>{};
        for (final hazard in state.hazards) {
          expect(state.blocks.contains(hazard.position), isFalse);
          expect(state.isShrinkLethal(hazard.position), isFalse);
          expect(
            seen.add(hazard.position),
            isTrue,
            reason: 'seed $seed stacked two telegraphs on one cell',
          );
        }
      }
    });
  });
}

/// One greedy step towards [target] on an obstruction free board, and the event
/// it produced.
TurnEvent? _stepOnceTowards(GameState state, TilePosition target) {
  if (state.player == target || !state.status.isRunning) {
    return null;
  }
  return kTurns.advance(state, actionTowards(state.player, target));
}
