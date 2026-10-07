import 'dart:math' as math;

import 'game_snapshot.dart';
import 'game_status.dart';
import 'hazard.dart';
import 'level_config.dart';
import 'moving_block.dart';
import 'player_action.dart';
import 'seeded_random.dart';
import 'tile_position.dart';

/// The mutable heart of Last Move.
///
/// This class is plain Dart on purpose: it holds every bit of gameplay state and
/// knows nothing about Flutter, Flame or rendering. The renderer only ever
/// *reads* from it.
///
/// A run is a chain of levels. Everything that belongs to a single level (walls,
/// hazards, sliding walls, the shrink, the exit) is rebuilt by [beginLevel], while
/// the run scoped values (score, total turns, the random stream) carry on.
class GameState {
  GameState({required this.seed, required this.config})
    : rng = SeededRandom(seed) {
    beginLevel(config);
  }

  /// Constructor used by [GameState.fromSnapshot] / [copy]; it does not build any
  /// initial world so the caller can restore one.
  GameState._blank({required this.seed, required this.config})
    : rng = SeededRandom(seed);

  factory GameState.fromSnapshot(GameSnapshot snapshot) {
    final state = GameState._blank(
      seed: snapshot.seed,
      config: snapshot.config,
    );
    state.turn = snapshot.turn;
    state.currentLevel = snapshot.currentLevel;
    state.levelTurn = snapshot.levelTurn;
    state.score = snapshot.score;
    state.status = snapshot.status;
    state.player = snapshot.player;
    state.hazards = List<Hazard>.of(snapshot.hazards);
    state.blocks = List<TilePosition>.of(snapshot.blocks);
    state.movingBlocks = List<MovingBlock>.of(snapshot.movingBlocks);
    state.shrinkLevel = snapshot.shrinkLevel;
    state.nextHazardId = snapshot.nextHazardId;
    state.recentMoves = List<PlayerAction>.of(snapshot.recentMoves);
    state.exitUnlocked = snapshot.exitUnlocked;
    state.exitPosition = snapshot.exitPosition;
    state.rng.state = snapshot.rngState;
    state.refreshDerived();
    return state;
  }

  /// The seed this run started from. Handy for debugging and bug reports.
  final int seed;

  /// Everything that defines the level currently being played.
  LevelConfig config;

  SeededRandom rng;

  /// Turns survived across the whole run.
  int turn = 0;

  /// 1-based level number. There is no last level.
  int currentLevel = 1;

  /// Turns survived inside the current level.
  int levelTurn = 0;

  int score = 0;
  GameStatus status = GameStatus.playing;
  TilePosition player = TilePosition.zero;

  /// Static walls.
  List<TilePosition> blocks = <TilePosition>[];

  /// Live telegraphs (pending / warning / danger).
  List<Hazard> hazards = <Hazard>[];

  /// Sliding walls.
  List<MovingBlock> movingBlocks = <MovingBlock>[];

  /// How many outer rings of the arena are already permanently lethal.
  int shrinkLevel = 0;

  int nextHazardId = 1;

  /// Most recent action first, capped so the generator only ever looks at a few.
  List<PlayerAction> recentMoves = <PlayerAction>[];

  /// `true` once the level's survival requirement has been met and the exit is
  /// on the board.
  bool exitUnlocked = false;

  /// Where the exit is, once [exitUnlocked]. Reaching it is the level's last move.
  TilePosition? exitPosition;

  // --- Derived, refreshed once per turn (so render never allocates) ----------

  /// Cells that kill the player at the end of the current turn.
  final Set<TilePosition> dangerCells = <TilePosition>{};

  /// Cells that currently show an amber warning.
  final Set<TilePosition> warningCells = <TilePosition>{};

  int get columns => config.columns;
  int get rows => config.rows;
  int get cellCount => columns * rows;
  int get turnsSurvived => turn;
  int get requiredSurvivalTurns => config.requiredSurvivalTurns;

  /// Turns still to survive before the exit opens.
  int get turnsUntilExit =>
      exitUnlocked ? 0 : math.max(0, requiredSurvivalTurns - levelTurn);

  /// How far through the level's survival phase the player is, 0..1.
  double get levelProgress => requiredSurvivalTurns <= 0
      ? 1
      : (levelTurn / requiredSurvivalTurns).clamp(0.0, 1.0);

  /// Turn on which the next ring of the arena becomes lethal.
  int get nextShrinkTurn =>
      config.shrinkStartTurn + shrinkLevel * config.shrinkInterval;

  /// How many rings are lethal on a given level turn.
  ///
  /// Capped by `LevelConfig.maxShrinkLevel`, and the exit is only ever placed
  /// outside of that cap, so the goal can never be swallowed by the shrink.
  int shrinkLevelAt(int forLevelTurn) {
    if (!config.hasShrink || forLevelTurn < config.shrinkStartTurn) {
      return 0;
    }
    final raw =
        1 + (forLevelTurn - config.shrinkStartTurn) ~/ config.shrinkInterval;
    return math.min(raw, config.maxShrinkLevel);
  }

  // --- Lifecycle -------------------------------------------------------------

  /// Wipes the previous level and builds the arena for [newConfig].
  ///
  /// Run scoped values ([score], [turn], [seed], the random stream) are kept on
  /// purpose: a run reads as one continuous chain of levels.
  void beginLevel(LevelConfig newConfig) {
    config = newConfig;
    currentLevel = newConfig.level;
    levelTurn = 0;
    status = GameStatus.playing;
    hazards = <Hazard>[];
    blocks = <TilePosition>[];
    movingBlocks = <MovingBlock>[];
    recentMoves = <PlayerAction>[];
    shrinkLevel = 0;
    nextHazardId = 1;
    exitUnlocked = false;
    exitPosition = null;
    player = TilePosition(newConfig.columns ~/ 2, newConfig.rows ~/ 2);
    spawnStaticBlocks(newConfig.blockCount);
    refreshDerived();
  }

  /// Starts a brand new run on [levelOne]. Used by PLAY and TRY AGAIN, which
  /// throw away score, level and history but never the stored best scores.
  void restartRun(LevelConfig levelOne) {
    turn = 0;
    score = 0;
    rng = SeededRandom(seed);
    beginLevel(levelOne);
  }

  /// Deep enough copy to simulate the future without touching the real game.
  GameState copy() => GameState.fromSnapshot(toSnapshot());

  GameSnapshot toSnapshot() {
    return GameSnapshot(
      seed: seed,
      config: config,
      rngState: rng.state,
      turn: turn,
      currentLevel: currentLevel,
      levelTurn: levelTurn,
      score: score,
      status: status,
      player: player,
      hazards: List<Hazard>.of(hazards),
      blocks: List<TilePosition>.of(blocks),
      movingBlocks: List<MovingBlock>.of(movingBlocks),
      shrinkLevel: shrinkLevel,
      nextHazardId: nextHazardId,
      recentMoves: List<PlayerAction>.of(recentMoves),
      exitUnlocked: exitUnlocked,
      exitPosition: exitPosition,
    );
  }

  /// Recomputes [dangerCells] and [warningCells] for the current turn.
  ///
  /// Called once per turn so the render loop can get away with plain set lookups
  /// and zero allocations.
  void refreshDerived() {
    dangerCells.clear();
    warningCells.clear();

    if (shrinkLevel > 0) {
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < columns; x++) {
          final position = TilePosition(x, y);
          if (ringIndexOf(position) < shrinkLevel) {
            dangerCells.add(position);
          }
        }
      }
    }

    for (final hazard in hazards) {
      switch (hazard.phaseAt(turn)) {
        case HazardPhase.warning:
          warningCells.add(hazard.position);
        case HazardPhase.danger:
          dangerCells.add(hazard.position);
        case HazardPhase.pending:
        case HazardPhase.expired:
          break;
      }
    }
  }

  // --- Geometry helpers ------------------------------------------------------

  bool contains(TilePosition position) =>
      position.x >= 0 &&
      position.y >= 0 &&
      position.x < columns &&
      position.y < rows;

  /// Distance from [position] to the closest arena edge (0 = outermost ring).
  int ringIndexOf(TilePosition position) {
    final fromLeft = position.x;
    final fromRight = columns - 1 - position.x;
    final fromTop = position.y;
    final fromBottom = rows - 1 - position.y;
    return math.min(
      math.min(fromLeft, fromRight),
      math.min(fromTop, fromBottom),
    );
  }

  bool isShrinkLethal(TilePosition position) =>
      ringIndexOf(position) < shrinkLevel;

  /// The ring that becomes lethal on [nextShrinkTurn].
  bool isShrinkWarning(TilePosition position) =>
      contains(position) &&
      config.hasShrink &&
      ringIndexOf(position) == shrinkLevel &&
      levelTurn >= nextShrinkTurn - 2 &&
      shrinkLevel < config.maxShrinkLevel;

  MovingBlock? movingBlockAt(TilePosition position) {
    for (final block in movingBlocks) {
      if (block.position == position) {
        return block;
      }
    }
    return null;
  }

  bool isStaticBlock(TilePosition position) => blocks.contains(position);

  bool isObstacle(TilePosition position) =>
      isStaticBlock(position) || movingBlockAt(position) != null;

  /// `true` when the player is allowed to enter [position].
  bool isWalkable(TilePosition position) =>
      contains(position) && !isObstacle(position);

  bool isLethal(TilePosition position) => dangerCells.contains(position);

  bool isExit(TilePosition position) =>
      exitUnlocked && exitPosition != null && exitPosition == position;

  /// The four orthogonal neighbours that are inside the arena.
  List<TilePosition> neighborsOf(TilePosition position) {
    final result = <TilePosition>[];
    for (final action in PlayerAction.values) {
      if (!action.isMovement) {
        continue;
      }
      final candidate = position + action.delta;
      if (contains(candidate)) {
        result.add(candidate);
      }
    }
    return result;
  }

  // --- Reachability ----------------------------------------------------------

  /// Flood fill of every cell the player can walk to, using the 4-neighbourhood.
  ///
  /// Call it after [refreshDerived] so that [avoidHazards] sees up to date
  /// telegraphs. This is what proves the exit is a reachable goal, and what keeps
  /// the generator from walling the player into a corner.
  Set<TilePosition> reachableCells({
    TilePosition? from,
    bool avoidHazards = false,
  }) {
    final start = from ?? player;
    final visited = <TilePosition>{start};
    final queue = <TilePosition>[start];
    var head = 0;

    while (head < queue.length) {
      final current = queue[head++];
      for (final neighbour in neighborsOf(current)) {
        if (visited.contains(neighbour)) {
          continue;
        }
        if (!_canWalkForRoute(neighbour, avoidHazards)) {
          continue;
        }
        visited.add(neighbour);
        queue.add(neighbour);
      }
    }
    return visited;
  }

  bool _canWalkForRoute(TilePosition cell, bool avoidHazards) {
    if (isObstacle(cell)) {
      return false;
    }
    if (isShrinkLethal(cell)) {
      return false;
    }
    if (avoidHazards && dangerCells.contains(cell)) {
      return false;
    }
    return true;
  }

  /// `true` when the player can walk to [destination] right now.
  bool canReach(TilePosition destination, {bool avoidHazards = false}) =>
      reachableCells(avoidHazards: avoidHazards).contains(destination);

  // --- Arena construction ----------------------------------------------------

  /// Scatters [count] static walls.
  ///
  /// The spawn cell and a two ring neighbourhood around it stay clear, and the
  /// result is validated with a flood fill so that an unlucky roll can never wall
  /// the player into a pocket on turn one.
  void spawnStaticBlocks(int count) {
    if (count <= 0) {
      return;
    }

    final protected = <TilePosition>{player};
    final immediate = neighborsOf(player);
    protected.addAll(immediate);
    for (final neighbour in immediate) {
      protected.addAll(neighborsOf(neighbour));
    }

    var attempts = 0;
    final maxAttempts = cellCount * 8;
    while (blocks.length < count && attempts < maxAttempts) {
      attempts++;
      final candidate = TilePosition(rng.nextInt(columns), rng.nextInt(rows));
      if (protected.contains(candidate) || blocks.contains(candidate)) {
        continue;
      }
      blocks.add(candidate);
    }

    _keepArenaConnected();
  }

  /// Opens the arena back up when the walls ended up sealing the player in.
  ///
  /// Removes walls that border the player's accessible area, one at a time, until
  /// at least half of the free cells can be reached again.
  void _keepArenaConnected() {
    var guard = 0;
    while (guard < 8) {
      guard++;
      final freeCells = cellCount - blocks.length;
      if (freeCells <= 0) {
        return;
      }

      final reachable = reachableCells();
      if (reachable.length * 2 >= freeCells) {
        return;
      }

      TilePosition? opener;
      for (final block in blocks) {
        if (neighborsOf(block).any(reachable.contains)) {
          opener = block;
          break;
        }
      }
      if (opener == null) {
        return;
      }
      blocks.remove(opener);
    }
  }
}
