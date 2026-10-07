import 'package:flutter/foundation.dart';

import 'game_status.dart';
import 'hazard.dart';
import 'level_config.dart';
import 'moving_block.dart';
import 'player_action.dart';
import 'tile_position.dart';

/// A complete, self contained copy of a single turn.
///
/// Second Chance relies on this: rewinding is a real restore of the world (player
/// position, score, the level and its exit, hazards, warnings, walls, moving
/// walls, arena shrink and the random stream) rather than teleporting the player
/// somewhere.
@immutable
class GameSnapshot {
  const GameSnapshot({
    required this.seed,
    required this.config,
    required this.rngState,
    required this.turn,
    required this.currentLevel,
    required this.levelTurn,
    required this.score,
    required this.status,
    required this.player,
    required this.hazards,
    required this.blocks,
    required this.movingBlocks,
    required this.shrinkLevel,
    required this.nextHazardId,
    required this.recentMoves,
    required this.exitUnlocked,
    this.exitPosition,
  });

  final int seed;

  /// Immutable, so sharing the reference with the live state is safe.
  final LevelConfig config;

  /// [SeededRandom.state] at the time of the snapshot.
  final int rngState;

  /// Turns survived across the whole run.
  final int turn;

  /// 1-based level number.
  final int currentLevel;

  /// Turns survived inside that level.
  final int levelTurn;

  final int score;
  final GameStatus status;
  final TilePosition player;
  final List<Hazard> hazards;
  final List<TilePosition> blocks;
  final List<MovingBlock> movingBlocks;
  final int shrinkLevel;
  final int nextHazardId;

  /// Most recent action first.
  final List<PlayerAction> recentMoves;

  /// Whether the exit was already open on this turn.
  final bool exitUnlocked;

  /// Where the exit is, when it is open.
  final TilePosition? exitPosition;

  int get columns => config.columns;
  int get rows => config.rows;
  int get turnsSurvived => turn;
  int get requiredSurvivalTurns => config.requiredSurvivalTurns;
  int get turnsUntilExit =>
      exitUnlocked ? 0 : (requiredSurvivalTurns - levelTurn).clamp(0, 9999);
}
