import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../models/game_state.dart';
import '../models/level_config.dart';
import '../models/seeded_random.dart';

/// How hard the world pushes back on one turn of a level.
///
/// Kept separate from [LevelConfig] because this is the *per turn* roll: the
/// config says how intense a level is, the profile says what happens right now.
@immutable
class DifficultyProfile {
  const DifficultyProfile({
    required this.hazardsToSpawn,
    required this.telegraphTurns,
    required this.dangerDuration,
    required this.maxConcurrentHazards,
    required this.movingBlockTarget,
  });

  /// Fresh telegraphs requested for this turn.
  final int hazardsToSpawn;

  /// Turns of amber warning before a telegraph turns lethal.
  final int telegraphTurns;

  /// How long a cell stays lethal once it fires.
  final int dangerDuration;

  /// Hard cap so a bad roll can never fill the board.
  final int maxConcurrentHazards;

  /// How many sliding walls should exist right now.
  final int movingBlockTarget;
}

/// Owns everything about levels: what a level *is*, and how a run moves from one
/// level to the next.
///
/// Levels are generated from their number, so there is no hand authored content
/// and no "final level": level 500 comes out of the same code as level 2. The
/// curve is stepped and soft capped rather than exponential, which keeps the
/// board readable (and the tiles big enough to see) forever.
class LevelSystem {
  const LevelSystem();

  /// First two turns of a level are always quiet, so a new level never opens by
  /// killing the player outright.
  static const int graceTurns = 2;

  /// Cycles that generate level variety. Levels 1-3 are forced to the plain
  /// configuration so the player can learn the loop first.
  static const List<LevelModifier> _modifierCycle = <LevelModifier>[
    LevelModifier.normal,
    LevelModifier.movingWalls,
    LevelModifier.normal,
    LevelModifier.tightArena,
    LevelModifier.normal,
    LevelModifier.hazardRush,
    LevelModifier.gauntlet,
  ];
  static const List<int> _gridCycle = <int>[8, 8, 7, 8, 8, 9];

  /// Hard limits that keep the game playable on a phone at any level.
  static const int minGridSize = 7;
  static const int maxGridSize = 9;
  static const int maxSurvivalTurns = 28;
  static const int maxConcurrentHazards = 6;
  static const int maxMovingBlocks = 4;

  LevelConfig configFor(int level) {
    final safeLevel = level < 1 ? 1 : level;
    final modifier = _modifierFor(safeLevel);
    final columns = _gridSizeFor(safeLevel, modifier);
    final requiredTurns = _requiredTurnsFor(safeLevel);
    final shrinkEnabled = _shrinkEnabledFor(safeLevel, modifier);
    final maxShrinkLevel = math.max(1, (columns - 4) ~/ 2);

    return LevelConfig(
      level: safeLevel,
      modifier: modifier,
      columns: columns,
      rows: columns,
      requiredSurvivalTurns: requiredTurns,
      blockCount: _blockCountFor(safeLevel, columns * columns, modifier),
      spawnChance: _spawnChanceFor(safeLevel, modifier),
      maxSpawnsPerTurn: _maxSpawnsFor(safeLevel, modifier),
      telegraphTurns: _telegraphTurnsFor(safeLevel),
      fastTelegraphChance: _fastTelegraphChanceFor(safeLevel),
      dangerDuration: 1,
      maxConcurrentHazards: _maxConcurrentFor(safeLevel, modifier),
      movingBlockCount: _movingBlocksFor(safeLevel, modifier),
      movingBlockPeriod: safeLevel < 12 ? 3 : 2,
      shrinkEnabled: shrinkEnabled,
      shrinkStartTurn: math.max(6, requiredTurns - 8),
      shrinkInterval: modifier == LevelModifier.tightArena ? 5 : 6,
      maxShrinkLevel: shrinkEnabled ? maxShrinkLevel : 0,
      exitMinDistance: _exitMinDistanceFor(safeLevel, columns),
    );
  }

  // --- Level table helpers ---------------------------------------------------

  LevelModifier _modifierFor(int level) {
    if (level <= 3) {
      return LevelModifier.normal;
    }
    return _modifierCycle[(level - 4) % _modifierCycle.length];
  }

  int _gridSizeFor(int level, LevelModifier modifier) {
    if (level <= 3) {
      return 8;
    }
    // A shrinking arena wants a little more room to close in on.
    if (modifier == LevelModifier.tightArena) {
      return 9;
    }
    return _gridCycle[level % _gridCycle.length];
  }

  /// Level 1 has to be genuinely easy, so the opening levels are hand set and
  /// everything after them grows by a slow, capped step.
  int _requiredTurnsFor(int level) {
    if (level <= 3) {
      return 6 + level * 2;
    }
    return math.min(12 + ((level - 3) * 3) ~/ 2, maxSurvivalTurns);
  }

  int _blockCountFor(int level, int cellCount, LevelModifier modifier) {
    if (level <= 1) {
      return 0;
    }
    final base = math.min(2 + (level - 2) ~/ 2, 9);
    final areaCap = cellCount ~/ 9;
    final extra = modifier == LevelModifier.gauntlet ? 1 : 0;
    return math.max(0, math.min(base, areaCap) + extra);
  }

  double _spawnChanceFor(int level, LevelModifier modifier) {
    var chance = math.min(0.35 + (level - 1) * 0.045, 1.0);
    if (modifier == LevelModifier.hazardRush) {
      chance += 0.15;
    }
    return chance.clamp(0.0, 1.0);
  }

  int _maxSpawnsFor(int level, LevelModifier modifier) {
    var spawns = level <= 4 ? 1 : (level <= 14 ? 2 : 3);
    if (modifier == LevelModifier.hazardRush) {
      spawns += 1;
    }
    return spawns.clamp(1, 3);
  }

  int _maxConcurrentFor(int level, LevelModifier modifier) {
    var value = 1 + level ~/ 3;
    if (modifier == LevelModifier.tightArena) {
      value -= 1;
    }
    return value.clamp(1, maxConcurrentHazards);
  }

  int _telegraphTurnsFor(int level) => level <= 2 ? 3 : 2;

  double _fastTelegraphChanceFor(int level) {
    if (level < 7) {
      return 0;
    }
    if (level < 12) {
      return 0.15;
    }
    if (level < 20) {
      return 0.3;
    }
    return 0.45;
  }

  int _movingBlocksFor(int level, LevelModifier modifier) {
    if (level < 4) {
      return 0;
    }
    if (modifier == LevelModifier.tightArena ||
        modifier == LevelModifier.hazardRush) {
      // Both already apply pressure their own way; stacking sliding walls on top
      // of a closed arena or a hazard flood is not fun, just unfair.
      return 0;
    }
    var count = math.min(1 + (level - 4) ~/ 8, 3);
    if (modifier == LevelModifier.movingWalls) {
      count += 1;
    }
    return count.clamp(0, maxMovingBlocks);
  }

  bool _shrinkEnabledFor(int level, LevelModifier modifier) =>
      modifier == LevelModifier.tightArena || level >= 25;

  int _exitMinDistanceFor(int level, int size) =>
      math.min(2 + (level - 1) ~/ 3, size);

  // --- Per turn --------------------------------------------------------------

  /// What the hazard generator is allowed to do on the current turn.
  DifficultyProfile profileFor(
    LevelConfig config,
    int levelTurn,
    SeededRandom rng,
  ) {
    if (levelTurn <= graceTurns) {
      return DifficultyProfile(
        hazardsToSpawn: 0,
        telegraphTurns: config.telegraphTurns,
        dangerDuration: config.dangerDuration,
        maxConcurrentHazards: config.maxConcurrentHazards,
        movingBlockTarget: 0,
      );
    }

    final spawns = rng.nextBool(config.spawnChance)
        ? config.maxSpawnsPerTurn
        : 0;

    return DifficultyProfile(
      hazardsToSpawn: spawns,
      telegraphTurns: _telegraphFor(config, rng),
      dangerDuration: config.dangerDuration,
      maxConcurrentHazards: config.maxConcurrentHazards,
      movingBlockTarget: config.movingBlockCount,
    );
  }

  int _telegraphFor(LevelConfig config, SeededRandom rng) {
    if (config.fastTelegraphChance > 0 &&
        rng.nextBool(config.fastTelegraphChance)) {
      return 1;
    }
    return config.telegraphTurns;
  }

  /// `true` while the next arena shrink is at most two turns away and the arena
  /// still has room to close.
  bool arenaWarning(LevelConfig config, int levelTurn, int shrinkLevel) {
    if (!config.hasShrink || shrinkLevel >= config.maxShrinkLevel) {
      return false;
    }
    final nextShrink =
        config.shrinkStartTurn + shrinkLevel * config.shrinkInterval;
    return nextShrink - levelTurn <= 2;
  }

  /// Turns still to survive before the exit opens (0 once it is open or due).
  int turnsUntilExit(GameState state) {
    if (state.exitUnlocked) {
      return 0;
    }
    return math.max(0, state.config.requiredSurvivalTurns - state.levelTurn);
  }

  /// There is deliberately no last level.
  int nextLevel(int currentLevel) => currentLevel + 1;
}
