import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The flavour of a level.
///
/// Levels are generated from their number, and the modifier is what makes two
/// levels with similar numbers feel different. It is shown to the player as a
/// short subtitle in the level intro banner so a run never feels samey.
enum LevelModifier {
  normal('NORMAL'),
  movingWalls('MOVING WALLS'),
  tightArena('TIGHT ARENA'),
  hazardRush('HAZARD RUSH'),
  gauntlet('GAUNTLET');

  const LevelModifier(this.label);

  /// Uppercase text shown in the level intro.
  final String label;
}

/// Everything that defines one level.
///
/// A [LevelConfig] is produced from the level number by `LevelSystem` and is
/// immutable, so it can be stored inside a `GameSnapshot` without worrying about
/// anyone mutating it behind the history's back.
@immutable
class LevelConfig {
  const LevelConfig({
    required this.level,
    required this.modifier,
    required this.columns,
    required this.rows,
    required this.requiredSurvivalTurns,
    required this.blockCount,
    required this.spawnChance,
    required this.maxSpawnsPerTurn,
    required this.telegraphTurns,
    required this.fastTelegraphChance,
    required this.dangerDuration,
    required this.maxConcurrentHazards,
    required this.movingBlockCount,
    required this.movingBlockPeriod,
    required this.shrinkEnabled,
    required this.shrinkStartTurn,
    required this.shrinkInterval,
    required this.maxShrinkLevel,
    required this.exitMinDistance,
  });

  /// 1-based level number.
  final int level;

  final LevelModifier modifier;

  /// Arena size. Kept inside 7..9 so tiles stay readable on a phone.
  final int columns;
  final int rows;

  /// How many turns the player has to survive before the exit opens.
  final int requiredSurvivalTurns;

  /// Static walls scattered at the start of the level.
  final int blockCount;

  /// Chance per turn that a telegraph is planted at all.
  final double spawnChance;

  /// Upper bound on telegraphs planted in a single turn.
  final int maxSpawnsPerTurn;

  /// Turns of amber warning before a telegraph turns lethal.
  final int telegraphTurns;

  /// Chance that a telegraph skips a turn of warning and fires sooner.
  final double fastTelegraphChance;

  /// How long a lethal cell stays lethal.
  final int dangerDuration;

  /// Hard cap on simultaneously live telegraphs.
  final int maxConcurrentHazards;

  /// Sliding walls present during the level.
  final int movingBlockCount;

  /// Turns between two steps of a sliding wall (smaller = faster).
  final int movingBlockPeriod;

  /// Whether the arena closes in during this level.
  final bool shrinkEnabled;

  /// Level turn on which the first ring becomes lethal.
  final int shrinkStartTurn;

  /// Level turns between two rings becoming lethal.
  final int shrinkInterval;

  /// How many outer rings may become lethal in total. The exit is always placed
  /// outside of this, so the goal can never be swallowed by the shrink.
  final int maxShrinkLevel;

  /// Minimum distance between the player and the exit when it opens.
  final int exitMinDistance;

  // --- Derived ---------------------------------------------------------------

  bool get hasShrink => shrinkEnabled && maxShrinkLevel > 0;

  /// Cells closer to the edge than this ring are (or will become) lethal, so the
  /// exit must stay outside of it.
  int get safeRingFloor => hasShrink ? maxShrinkLevel : 0;

  /// Distance the exit placement prefers; the roll peaks here and falls off.
  int get exitPreferredDistance =>
      math.min(exitMinDistance + 2, math.max(columns, rows));

  int get cellCount => columns * rows;

  /// Rough single number for comparing two levels. Only used for tests and
  /// balancing, never for gameplay.
  double get difficultyScore =>
      requiredSurvivalTurns +
      maxConcurrentHazards * 4 +
      maxSpawnsPerTurn * 3 +
      movingBlockCount * 3 +
      spawnChance * 10 +
      telegraphTurns * -1.5 +
      (hasShrink ? 6 : 0) +
      exitMinDistance;

  String get sizeLabel => '$columns×$rows';

  LevelConfig copyWith({
    int? level,
    LevelModifier? modifier,
    int? columns,
    int? rows,
    int? requiredSurvivalTurns,
    int? blockCount,
    double? spawnChance,
    int? maxSpawnsPerTurn,
    int? telegraphTurns,
    double? fastTelegraphChance,
    int? dangerDuration,
    int? maxConcurrentHazards,
    int? movingBlockCount,
    int? movingBlockPeriod,
    bool? shrinkEnabled,
    int? shrinkStartTurn,
    int? shrinkInterval,
    int? maxShrinkLevel,
    int? exitMinDistance,
  }) {
    return LevelConfig(
      level: level ?? this.level,
      modifier: modifier ?? this.modifier,
      columns: columns ?? this.columns,
      rows: rows ?? this.rows,
      requiredSurvivalTurns:
          requiredSurvivalTurns ?? this.requiredSurvivalTurns,
      blockCount: blockCount ?? this.blockCount,
      spawnChance: spawnChance ?? this.spawnChance,
      maxSpawnsPerTurn: maxSpawnsPerTurn ?? this.maxSpawnsPerTurn,
      telegraphTurns: telegraphTurns ?? this.telegraphTurns,
      fastTelegraphChance: fastTelegraphChance ?? this.fastTelegraphChance,
      dangerDuration: dangerDuration ?? this.dangerDuration,
      maxConcurrentHazards: maxConcurrentHazards ?? this.maxConcurrentHazards,
      movingBlockCount: movingBlockCount ?? this.movingBlockCount,
      movingBlockPeriod: movingBlockPeriod ?? this.movingBlockPeriod,
      shrinkEnabled: shrinkEnabled ?? this.shrinkEnabled,
      shrinkStartTurn: shrinkStartTurn ?? this.shrinkStartTurn,
      shrinkInterval: shrinkInterval ?? this.shrinkInterval,
      maxShrinkLevel: maxShrinkLevel ?? this.maxShrinkLevel,
      exitMinDistance: exitMinDistance ?? this.exitMinDistance,
    );
  }

  @override
  String toString() =>
      'LevelConfig(level: $level, ${modifier.name}, '
      '$columns×$rows, survive: $requiredSurvivalTurns)';
}
