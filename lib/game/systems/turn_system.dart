import '../models/game_rules.dart';
import '../models/game_state.dart';
import '../models/game_status.dart';
import '../models/moving_block.dart';
import '../models/player_action.dart';
import '../models/tile_position.dart';
import '../models/turn_event.dart';
import 'exit_system.dart';
import 'hazard_system.dart';
import 'level_system.dart';

/// Advances the world by exactly one turn.
///
/// The whole game is turn based: nothing here runs on a timer, so the Flame
/// update loop and the gameplay can never get tangled. `advance` also has no side
/// effects outside [state], which is what lets the future preview clone the state
/// and call it a few times.
class TurnSystem {
  const TurnSystem({
    LevelSystem levels = const LevelSystem(),
    HazardSystem hazards = const HazardSystem(),
    ExitSystem exits = const ExitSystem(),
  }) : _levels = levels,
       _hazards = hazards,
       _exits = exits;

  final LevelSystem _levels;
  final HazardSystem _hazards;
  final ExitSystem _exits;

  static const List<TilePosition> _directions = <TilePosition>[
    TilePosition(0, -1),
    TilePosition(0, 1),
    TilePosition(-1, 0),
    TilePosition(1, 0),
  ];

  /// Applies [action] and then steps the world forward.
  TurnEvent advance(GameState state, PlayerAction action) {
    if (state.status != GameStatus.playing) {
      return TurnEvent.rejected(turn: state.turn);
    }

    final target = state.player + action.delta;
    if (action.isMovement && !state.isWalkable(target)) {
      // Walking into a wall or a sliding wall does not cost a turn: the player
      // has an explicit "wait" action for spending time.
      return TurnEvent.rejected(turn: state.turn);
    }

    // The level's last move. Stepping onto the open exit finishes the level right
    // there - no hazard, sliding wall or ring gets to act on that turn.
    if (action.isMovement && state.isExit(target)) {
      return _completeLevel(state, action, target);
    }

    if (action.isMovement) {
      state.player = target;
    }

    final turn = state.turn + 1;
    final levelTurn = state.levelTurn + 1;
    state.turn = turn;
    state.levelTurn = levelTurn;
    _rememberMove(state, action);

    final profile = _levels.profileFor(state.config, levelTurn, state.rng);

    // 1. sliding walls take their step.
    final movingBlockMoves = _advanceMovingBlocks(
      state,
      turn,
      profile.movingBlockTarget,
    );

    // 2. hazards that already resolved are cleared away.
    state.hazards.removeWhere((hazard) => hazard.dangerUntilTurn <= turn);

    // 3. the arena closes in - only on levels that ask for it, and capped so the
    //    exit (which is placed outside the cap) can never be swallowed.
    final shrinkLevel = state.shrinkLevelAt(levelTurn);
    final shrank = shrinkLevel > state.shrinkLevel;
    state.shrinkLevel = shrinkLevel;

    // 4. fresh telegraphs, placed with the move the player just made in mind.
    final warningsCreated = _hazards.spawnTelegraphs(
      state,
      turn: turn,
      profile: profile,
    );

    state.refreshDerived();

    // 5. score for surviving the turn.
    state.score += GameRules.scorePerTurn;

    // 6. did the player survive the turn they just took?
    final dangersActivated = _countDangersFiring(state, turn);
    final arenaWarning = _levels.arenaWarning(
      state.config,
      levelTurn,
      state.shrinkLevel,
    );

    if (state.dangerCells.contains(state.player)) {
      state.status = GameStatus.gameOver;
      return TurnEvent(
        turn: turn,
        accepted: true,
        died: true,
        dangersActivated: dangersActivated,
        warningsCreated: warningsCreated,
        movingBlockMoves: movingBlockMoves,
        arenaShrink: shrank,
        arenaWarning: arenaWarning,
      );
    }

    // 7. the survival requirement may have just been met: open the exit.
    var exitOpened = false;
    if (!state.exitUnlocked &&
        levelTurn >= state.config.requiredSurvivalTurns) {
      exitOpened = _exits.placeExit(state, state.config);
      state.exitUnlocked = exitOpened;
    }

    // 8. an open exit keeps a route to it, whatever the sliding walls do.
    if (state.exitUnlocked) {
      _exits.ensureRouteOpen(state);
    }

    return TurnEvent(
      turn: turn,
      accepted: true,
      dangersActivated: dangersActivated,
      warningsCreated: warningsCreated,
      movingBlockMoves: movingBlockMoves,
      arenaShrink: shrank,
      arenaWarning: arenaWarning,
      exitOpened: exitOpened,
    );
  }

  /// The player walked into the exit: this is the level's last move.
  TurnEvent _completeLevel(
    GameState state,
    PlayerAction action,
    TilePosition exit,
  ) {
    state.turn += 1;
    state.levelTurn += 1;
    state.player = exit;
    _rememberMove(state, action);

    final bonus = GameRules.scorePerLevel * state.currentLevel;
    state.score += GameRules.scorePerTurn + bonus;
    state.status = GameStatus.levelComplete;
    state.refreshDerived();

    return TurnEvent(
      turn: state.turn,
      accepted: true,
      levelCompleted: true,
      levelBonus: bonus,
    );
  }

  void _rememberMove(GameState state, PlayerAction action) {
    state.recentMoves.insert(0, action);
    if (state.recentMoves.length > GameRules.recentMoveMemory) {
      state.recentMoves.removeRange(
        GameRules.recentMoveMemory,
        state.recentMoves.length,
      );
    }
  }

  int _countDangersFiring(GameState state, int turn) {
    var count = 0;
    for (final hazard in state.hazards) {
      if (hazard.dangerFromTurn == turn) {
        count++;
      }
    }
    return count;
  }

  // --- Sliding walls ---------------------------------------------------------

  int _advanceMovingBlocks(GameState state, int turn, int target) {
    _syncMovingBlockCount(state, turn, target);

    var moves = 0;
    for (var i = 0; i < state.movingBlocks.length; i++) {
      final block = state.movingBlocks[i];
      if (turn < block.nextMoveTurn) {
        continue;
      }
      final step = _step(state, block);
      state.movingBlocks[i] = block.copyWith(
        position: step.position,
        dx: step.dx,
        dy: step.dy,
        nextMoveTurn: turn + block.period,
      );
      if (step.position != block.position) {
        moves++;
      }
    }
    return moves;
  }

  /// One step for [block]: forward if possible, otherwise bounce off whatever is
  /// in the way.
  ({TilePosition position, int dx, int dy}) _step(
    GameState state,
    MovingBlock block,
  ) {
    final ahead = block.position + TilePosition(block.dx, block.dy);
    if (_canEnter(state, ahead)) {
      return (position: ahead, dx: block.dx, dy: block.dy);
    }

    final reversedX = -block.dx;
    final reversedY = -block.dy;
    final behind = block.position + TilePosition(reversedX, reversedY);
    if (_canEnter(state, behind)) {
      return (position: behind, dx: reversedX, dy: reversedY);
    }

    return (position: block.position, dx: reversedX, dy: reversedY);
  }

  bool _canEnter(GameState state, TilePosition cell) {
    if (!state.contains(cell)) {
      return false;
    }
    if (state.isStaticBlock(cell)) {
      return false;
    }
    if (state.isShrinkLethal(cell)) {
      return false;
    }
    // A wall never parks on the exit, so the goal always stays enterable.
    if (state.isExit(cell)) {
      return false;
    }
    if (cell == state.player) {
      // A wall never crushes the player; it simply refuses to move there.
      return false;
    }
    for (final other in state.movingBlocks) {
      if (other.position == cell) {
        return false;
      }
    }
    return true;
  }

  void _syncMovingBlockCount(GameState state, int turn, int target) {
    while (state.movingBlocks.length > target) {
      state.movingBlocks.removeLast();
    }

    var attempts = 0;
    while (state.movingBlocks.length < target && attempts < 40) {
      attempts++;
      final spawn = _pickMovingBlock(state, turn);
      if (spawn == null) {
        return;
      }
      state.movingBlocks.add(spawn);
    }
  }

  MovingBlock? _pickMovingBlock(GameState state, int turn) {
    final candidates = <TilePosition>[];
    for (var y = 0; y < state.rows; y++) {
      for (var x = 0; x < state.columns; x++) {
        final cell = TilePosition(x, y);
        if (state.isObstacle(cell) ||
            state.isShrinkLethal(cell) ||
            state.isExit(cell)) {
          continue;
        }
        // Never materialise right on top of the player.
        if (cell.manhattanDistanceTo(state.player) < 3) {
          continue;
        }
        if (_usableDirections(state, cell).isEmpty) {
          continue;
        }
        candidates.add(cell);
      }
    }
    if (candidates.isEmpty) {
      return null;
    }

    final cell = candidates[state.rng.nextInt(candidates.length)];
    final usable = _usableDirections(state, cell);
    if (usable.isEmpty) {
      return null;
    }
    final direction = usable[state.rng.nextInt(usable.length)];
    final period = state.config.movingBlockPeriod;

    return MovingBlock(
      position: cell,
      dx: direction.x,
      dy: direction.y,
      period: period,
      nextMoveTurn: turn + period,
    );
  }

  List<TilePosition> _usableDirections(GameState state, TilePosition cell) {
    return <TilePosition>[
      for (final direction in _directions)
        if (_canEnter(state, cell + direction)) direction,
    ];
  }
}
