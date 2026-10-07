import '../models/game_state.dart';
import '../models/level_config.dart';
import '../models/tile_position.dart';

/// Places the level exit and keeps a real route to it open.
///
/// This is the system that makes the new goal honest: the exit is never dropped
/// somewhere decorative. It only ever appears on a cell the player can actually
/// walk to *right now*, outside the shrinking core, free of telegraphs and far
/// enough away to be a journey.
///
/// The flood fill itself lives on `GameState` (`reachableCells` / `canReach`),
/// next to the other arena geometry helpers, so there is exactly one
/// implementation of it.
class ExitSystem {
  const ExitSystem();

  /// `true` when the player can still walk to the open exit.
  bool hasRouteToExit(GameState state, {bool avoidHazards = false}) {
    final exit = state.exitPosition;
    if (exit == null) {
      return false;
    }
    return state.canReach(exit, avoidHazards: avoidHazards);
  }

  /// Chooses where the exit appears.
  ///
  /// Returns `false` only when the arena genuinely offers no valid cell, in which
  /// case the caller leaves the exit locked and simply tries again next turn.
  bool placeExit(GameState state, LevelConfig config) {
    final strict = _candidates(
      state,
      config,
      state.reachableCells(avoidHazards: true),
      strict: true,
    );

    // Fallback: allow cells that are telegraphed right now (telegraphs clear) and
    // drop the distance requirement down to "not under the player".
    final relaxed = strict.isNotEmpty
        ? strict
        : _candidates(state, config, state.reachableCells(), strict: false);

    if (relaxed.isEmpty) {
      return false;
    }

    state.exitPosition = _weightedPick(state, config, relaxed);
    return true;
  }

  List<TilePosition> _candidates(
    GameState state,
    LevelConfig config,
    Set<TilePosition> reachable, {
    required bool strict,
  }) {
    final floor = config.safeRingFloor;
    final minDistance = strict ? config.exitMinDistance : 1;
    final result = <TilePosition>[];

    for (final cell in reachable) {
      if (cell == state.player) {
        continue;
      }
      // Never inside the part of the arena that the shrink will swallow.
      if (state.ringIndexOf(cell) < floor) {
        continue;
      }
      if (state.dangerCells.contains(cell)) {
        continue;
      }
      if (strict && state.warningCells.contains(cell)) {
        continue;
      }
      if (cell.manhattanDistanceTo(state.player) < minDistance) {
        continue;
      }
      result.add(cell);
    }
    return result;
  }

  /// Weighted roll that peaks at the level's preferred distance and falls off
  /// gently, so the exit wanders further away as levels go on without ever
  /// always landing in the same corner.
  TilePosition _weightedPick(
    GameState state,
    LevelConfig config,
    List<TilePosition> candidates,
  ) {
    final preferred = config.exitPreferredDistance;
    final weights = <double>[];
    var total = 0.0;

    for (final cell in candidates) {
      final spread = (cell.manhattanDistanceTo(state.player) - preferred).abs();
      final weight = 1.0 / (1.0 + spread);
      weights.add(weight);
      total += weight;
    }

    var roll = state.rng.nextDouble() * total;
    for (var i = 0; i < candidates.length; i++) {
      roll -= weights[i];
      if (roll <= 0) {
        return candidates[i];
      }
    }
    return candidates.last;
  }

  /// Fairness recovery.
  ///
  /// Called every turn once the exit is open. Static walls and the shrink never
  /// change during a level, and placement already proved a route through them, so
  /// the only thing that can seal the exit is a sliding wall parking in the way.
  /// When that happens the most recently spawned wall steps aside.
  ///
  /// Deliberately ignores temporary telegraphs: waiting a turn or two for a cell
  /// to stop burning is a legitimate part of the game.
  bool ensureRouteOpen(GameState state) {
    if (!state.exitUnlocked || state.exitPosition == null) {
      return true;
    }
    if (hasRouteToExit(state)) {
      return true;
    }

    var attempts = 0;
    while (attempts < 3 && state.movingBlocks.isNotEmpty) {
      attempts++;
      state.movingBlocks.removeLast();
      if (hasRouteToExit(state)) {
        return true;
      }
    }
    return hasRouteToExit(state);
  }
}
