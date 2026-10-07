import 'package:flutter/foundation.dart';

/// What happened while the world advanced by one turn.
///
/// The turn system returns this instead of reaching into the UI so that the
/// future preview can reuse the exact same simulation.
@immutable
class TurnEvent {
  const TurnEvent({
    required this.turn,
    required this.accepted,
    this.died = false,
    this.dangersActivated = 0,
    this.warningsCreated = 0,
    this.movingBlockMoves = 0,
    this.arenaShrink = false,
    this.arenaWarning = false,
    this.exitOpened = false,
    this.levelCompleted = false,
    this.levelBonus = 0,
  });

  /// The action was refused (a wall, a moving block or the arena edge) and the
  /// world did not advance.
  const TurnEvent.rejected({required this.turn})
    : accepted = false,
      died = false,
      dangersActivated = 0,
      warningsCreated = 0,
      movingBlockMoves = 0,
      arenaShrink = false,
      arenaWarning = false,
      exitOpened = false,
      levelCompleted = false,
      levelBonus = 0;

  /// Turn number the world is at after the event.
  final int turn;

  /// `false` when the player's action was refused and time did not pass.
  final bool accepted;

  final bool died;

  /// Telegraphs that turned lethal on this turn.
  final int dangersActivated;

  /// Fresh warnings that appeared on this turn.
  final int warningsCreated;

  /// How many walls actually changed cell.
  final int movingBlockMoves;

  /// The arena lost a ring on this turn.
  final bool arenaShrink;

  /// An arena shrink is within the next two turns.
  final bool arenaWarning;

  /// The survival requirement was just met and the exit appeared.
  final bool exitOpened;

  /// The player's move landed on the exit: this was the level's last move.
  final bool levelCompleted;

  /// Points awarded for finishing the level (already added to the score).
  final int levelBonus;
}
