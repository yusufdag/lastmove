import 'package:last_move/game/game_controller.dart';
import 'package:last_move/game/models/game_state.dart';
import 'package:last_move/game/models/hazard.dart';
import 'package:last_move/game/models/player_action.dart';
import 'package:last_move/game/models/tile_position.dart';
import 'package:last_move/game/services/score_service.dart';
import 'package:last_move/game/systems/level_system.dart';
import 'package:last_move/game/systems/turn_system.dart';

/// Shared fixtures for the gameplay tests.
const LevelSystem kLevels = LevelSystem();
const TurnSystem kTurns = TurnSystem(levels: kLevels);

/// A brand new state for [level] of a fresh run using [seed].
GameState newState(
  int seed, {
  int level = 1,
  int? columns,
  int? rows,
  bool? shrinkEnabled,
}) {
  var config = kLevels.configFor(level);
  if (columns != null || rows != null || shrinkEnabled != null) {
    config = config.copyWith(
      columns: columns ?? config.columns,
      rows: rows ?? config.rows,
      shrinkEnabled: shrinkEnabled ?? config.shrinkEnabled,
    );
  }
  return GameState(seed: seed, config: config);
}

/// A controller with a fixed seed and pristine mocked storage.
GameController newController({required int seed}) =>
    GameController(seed: seed, scoreService: ScoreService());

/// The first walkable cell exactly [distance] Manhattan steps from the player.
TilePosition? openCellAt(GameState state, {required int distance}) {
  for (var y = 0; y < state.rows; y++) {
    for (var x = 0; x < state.columns; x++) {
      final cell = TilePosition(x, y);
      if (cell.manhattanDistanceTo(state.player) != distance) {
        continue;
      }
      if (!state.isWalkable(cell)) {
        continue;
      }
      return cell;
    }
  }
  return null;
}

/// One step from [from] towards [to], by sign, so it also works for targets
/// several cells away (x is closed first, then y, which is enough on the empty
/// boards these tests build).
PlayerAction actionTowards(TilePosition from, TilePosition to) {
  final dx = to.x - from.x;
  final dy = to.y - from.y;
  if (dx > 0) {
    return PlayerAction.right;
  }
  if (dx < 0) {
    return PlayerAction.left;
  }
  if (dy > 0) {
    return PlayerAction.down;
  }
  if (dy < 0) {
    return PlayerAction.up;
  }
  return PlayerAction.wait;
}

/// Drops an open exit one step away from the player, so a test can take the
/// level's last move without first surviving the whole level.
bool unlockExitNextToPlayer(GameState state) {
  final cell = openCellAt(state, distance: 1);
  if (cell == null) {
    return false;
  }
  state.exitUnlocked = true;
  state.exitPosition = cell;
  state.refreshDerived();
  return true;
}

/// Finishes the current level through the controller: walks into the exit and
/// steps the transition timer.
bool clearCurrentLevel(GameController controller) {
  final state = controller.state;
  if (!unlockExitNextToPlayer(state)) {
    return false;
  }
  controller.perform(actionTowards(state.player, state.exitPosition!));
  if (!controller.status.isLevelComplete) {
    return false;
  }
  controller.advanceToNextLevel();
  return true;
}

/// Plays until the controller reaches [level] (bounded so a broken generator can
/// never hang the suite).
bool runToLevel(GameController controller, int level) {
  var guard = 0;
  while (controller.currentLevel < level && guard < level * 3 + 8) {
    guard++;
    if (!clearCurrentLevel(controller)) {
      return false;
    }
  }
  return controller.currentLevel >= level;
}

/// Strips the current level of everything that can end a run by itself, so a
/// test can spend turns without the generator deciding the outcome for it.
void pacifyController(GameController controller) {
  controller.state.config = controller.state.config.copyWith(
    spawnChance: 0,
    movingBlockCount: 0,
    shrinkEnabled: false,
    maxShrinkLevel: 0,
  );
}

/// Plants an unavoidable lethal cell under the player and spends the turn, so the
/// run ends on a known level.
void killCurrentRun(GameController controller) {
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
