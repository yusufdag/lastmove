import 'package:flutter/foundation.dart';

import 'tile_position.dart';

/// Lifecycle of a single hazard cell.
enum HazardPhase {
  /// Scheduled for a future turn - completely invisible to the player.
  pending,

  /// Visible warning (amber). The player can still walk over it safely.
  warning,

  /// Lethal (red). Standing here at the end of a turn ends the run.
  danger,

  /// Already resolved and safe again.
  expired,
}

/// A telegraph that becomes lethal after [warningFromTurn] has passed.
///
/// The object is immutable on purpose: game history stores lists of hazards
/// directly, so nothing may mutate behind the snapshot's back.
@immutable
class Hazard {
  const Hazard({
    required this.id,
    required this.position,
    required this.warningFromTurn,
    required this.dangerFromTurn,
    required this.dangerUntilTurn,
  });

  /// Monotonically increasing id. Used to decide which hazard was created last
  /// when the fairness pass has to remove one.
  final int id;

  final TilePosition position;

  /// First turn on which the amber warning is drawn (inclusive).
  final int warningFromTurn;

  /// First turn on which the cell is lethal (inclusive).
  final int dangerFromTurn;

  /// First turn on which the cell is safe again (exclusive).
  final int dangerUntilTurn;

  HazardPhase phaseAt(int turn) {
    if (turn < warningFromTurn) {
      return HazardPhase.pending;
    }
    if (turn < dangerFromTurn) {
      return HazardPhase.warning;
    }
    if (turn < dangerUntilTurn) {
      return HazardPhase.danger;
    }
    return HazardPhase.expired;
  }

  bool isLethalAt(int turn) => phaseAt(turn) == HazardPhase.danger;

  bool isVisibleAt(int turn) {
    final phase = phaseAt(turn);
    return phase == HazardPhase.warning || phase == HazardPhase.danger;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Hazard &&
          other.id == id &&
          other.position == position &&
          other.warningFromTurn == warningFromTurn &&
          other.dangerFromTurn == dangerFromTurn &&
          other.dangerUntilTurn == dangerUntilTurn;

  @override
  int get hashCode => Object.hash(
    id,
    position,
    warningFromTurn,
    dangerFromTurn,
    dangerUntilTurn,
  );

  @override
  String toString() =>
      'Hazard#$id $position warn@$warningFromTurn fire@$dangerFromTurn '
      'until@$dangerUntilTurn';
}
