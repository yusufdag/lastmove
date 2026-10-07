import 'dart:math' as math;

import '../models/game_state.dart';
import '../models/hazard.dart';
import '../models/player_action.dart';
import '../models/seeded_random.dart';
import '../models/tile_position.dart';
import 'level_system.dart';

/// Decides *where* the next hazards appear.
///
/// This is the system that gives Last Move its identity. Cells are picked with a
/// weighted random roll, and the weights depend on:
///
/// * how close the cell is to the player,
/// * the direction the player has been drifting over their last few moves,
/// * the seeded random stream.
///
/// The result is that every move nudges the *next few turns*, so the player is
/// always one decision away from "I should have gone the other way" - without
/// the generator simply mirroring the player's position.
class HazardSystem {
  const HazardSystem();

  /// How many recent moves the "which way is the player drifting" bias uses.
  static const int _trendWindow = 3;

  /// Adds fresh telegraphs for [turn] and returns how many were created.
  int spawnTelegraphs(
    GameState state, {
    required int turn,
    required DifficultyProfile profile,
  }) {
    if (profile.hazardsToSpawn <= 0) {
      return 0;
    }

    final activeCount = state.hazards
        .where((h) => h.phaseAt(turn) != HazardPhase.expired)
        .length;
    final budget = profile.maxConcurrentHazards - activeCount;
    final requested = math.min(profile.hazardsToSpawn, math.max(0, budget));
    if (requested <= 0) {
      return 0;
    }

    final candidates = _candidateCells(state, turn);
    if (candidates.isEmpty) {
      return 0;
    }

    final weights = <double>[
      for (final cell in candidates) _weightFor(state, cell),
    ];
    final pool = <int>[for (var i = 0; i < candidates.length; i++) i];

    final chosen = <TilePosition>[];
    final pickCount = math.min(requested, pool.length);
    for (var i = 0; i < pickCount; i++) {
      final index = _weightedPick(pool, weights, state.rng);
      chosen.add(candidates[pool.removeAt(index)]);
    }

    for (final cell in chosen) {
      state.hazards.add(
        Hazard(
          id: state.nextHazardId++,
          position: cell,
          warningFromTurn: turn,
          dangerFromTurn: turn + profile.telegraphTurns,
          dangerUntilTurn:
              turn + profile.telegraphTurns + profile.dangerDuration,
        ),
      );
    }

    _relaxDeadlyTraps(state);
    return chosen.length;
  }

  /// Cells that are allowed to receive a new telegraph.
  List<TilePosition> _candidateCells(GameState state, int turn) {
    final result = <TilePosition>[];
    for (var y = 0; y < state.rows; y++) {
      for (var x = 0; x < state.columns; x++) {
        final cell = TilePosition(x, y);
        if (state.isObstacle(cell)) {
          continue;
        }
        if (state.isShrinkLethal(cell)) {
          continue;
        }
        // The exit is sacred ground: it stays walkable for the whole level so the
        // goal can never be taken away from the player.
        if (state.isExit(cell)) {
          continue;
        }
        if (_isTelegraphed(state, cell, turn)) {
          continue;
        }
        result.add(cell);
      }
    }
    return result;
  }

  bool _isTelegraphed(GameState state, TilePosition cell, int turn) {
    for (final hazard in state.hazards) {
      if (hazard.position != cell) {
        continue;
      }
      final phase = hazard.phaseAt(turn);
      if (phase == HazardPhase.warning || phase == HazardPhase.danger) {
        return true;
      }
    }
    return false;
  }

  /// Relative chance of picking [cell] for the next telegraph.
  ///
  /// Beating the player by mirroring them would feel like cheating, so the bias
  /// is soft: adjacent cells are preferred, far cells still get picked, and the
  /// player's own cell only gets a small nudge.
  double _weightFor(GameState state, TilePosition cell) {
    final distance = cell.manhattanDistanceTo(state.player);
    final double distanceWeight;
    if (distance == 0) {
      distanceWeight = 1.3;
    } else if (distance == 1) {
      distanceWeight = 3.2;
    } else if (distance == 2) {
      distanceWeight = 1.9;
    } else if (distance == 3) {
      distanceWeight = 1.3;
    } else {
      distanceWeight = 1.0;
    }

    var weight = distanceWeight;

    // Bias towards the direction the player has been drifting in.
    final trend = _movementTrend(state.recentMoves);
    if (trend != TilePosition.zero) {
      final delta = cell - state.player;
      final alignment = delta.x * trend.x + delta.y * trend.y;
      if (alignment > 0) {
        weight *= 1.6;
      } else if (alignment < 0) {
        weight *= 0.85;
      }
    }

    return weight;
  }

  /// Sum of the last few movement vectors, collapsed to a direction.
  TilePosition _movementTrend(List<PlayerAction> recentMoves) {
    var dx = 0;
    var dy = 0;
    final window = math.min(_trendWindow, recentMoves.length);
    for (var i = 0; i < window; i++) {
      dx += recentMoves[i].dx;
      dy += recentMoves[i].dy;
    }
    return TilePosition(dx.sign, dy.sign);
  }

  int _weightedPick(List<int> pool, List<double> weights, SeededRandom rng) {
    var total = 0.0;
    for (final index in pool) {
      total += weights[index];
    }
    if (total <= 0) {
      return rng.nextInt(pool.length);
    }

    var roll = rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      roll -= weights[pool[i]];
      if (roll <= 0) {
        return i;
      }
    }
    return pool.length - 1;
  }

  /// Fairness valve.
  ///
  /// If the freshly created telegraphs would make a future turn a certain death
  /// (the player's own cell is lethal *and* every escape is blocked), the newest
  /// hazard involved is dropped again. Without this the weighted rolls could
  /// occasionally build an unwinnable corner, which reads as a bug rather than
  /// as difficulty.
  void _relaxDeadlyTraps(GameState state) {
    final fireTurns = <int>{};
    for (final hazard in state.hazards) {
      if (hazard.phaseAt(state.turn) == HazardPhase.expired) {
        continue;
      }
      if (hazard.dangerFromTurn >= state.turn) {
        fireTurns.add(hazard.dangerFromTurn);
      }
    }

    final sorted = fireTurns.toList()..sort();
    for (final fireTurn in sorted.take(4)) {
      if (!_isDeadlyTrap(state, fireTurn)) {
        continue;
      }
      final lethal = <Hazard>[
        for (final hazard in state.hazards)
          if (hazard.dangerFromTurn <= fireTurn &&
              fireTurn < hazard.dangerUntilTurn)
            hazard,
      ];
      if (lethal.isEmpty) {
        continue;
      }
      lethal.sort((a, b) => b.id.compareTo(a.id));
      state.hazards.remove(lethal.first);
    }
  }

  bool _isDeadlyTrap(GameState state, int turn) {
    final lethalCells = <TilePosition>{
      for (final hazard in state.hazards)
        if (hazard.dangerFromTurn <= turn && turn < hazard.dangerUntilTurn)
          hazard.position,
    };

    final shrinkLevel = state.shrinkLevelAt(
      state.levelTurn + (turn - state.turn),
    );
    if (shrinkLevel > 0) {
      for (var y = 0; y < state.rows; y++) {
        for (var x = 0; x < state.columns; x++) {
          final cell = TilePosition(x, y);
          if (state.ringIndexOf(cell) < shrinkLevel) {
            lethalCells.add(cell);
          }
        }
      }
    }

    if (!lethalCells.contains(state.player)) {
      // Standing still is survivable, so there is always an out.
      return false;
    }

    // A wall can never be occupied, so it is not a usable escape either.
    for (final neighbour in state.neighborsOf(state.player)) {
      if (state.isObstacle(neighbour)) {
        continue;
      }
      if (!lethalCells.contains(neighbour)) {
        return false;
      }
    }
    return true;
  }
}
