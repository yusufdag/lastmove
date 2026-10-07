import 'package:flutter/foundation.dart';

/// One card of the `NEXT / +1 / +2 / +3` strip above the controls.
///
/// It deliberately exposes counts and categories only - never the exact cells.
/// The player gets enough information to plan, but the generator still has room
/// to punish a careless move.
@immutable
class FutureTurnPreview {
  const FutureTurnPreview({
    required this.turnsAhead,
    this.dangers = 0,
    this.warnings = 0,
    this.movingBlockMoves = 0,
    this.arenaShrink = false,
    this.arenaWarning = false,
  });

  /// `1` means "one turn from now".
  final int turnsAhead;

  /// Telegraphs that become lethal on that turn.
  final int dangers;

  /// New warnings that appear on that turn.
  final int warnings;

  /// Walls that step on that turn.
  final int movingBlockMoves;

  /// The arena loses a ring on that turn.
  final bool arenaShrink;

  /// A shrink is coming soon.
  final bool arenaWarning;

  bool get hasActivity =>
      dangers > 0 ||
      warnings > 0 ||
      movingBlockMoves > 0 ||
      arenaShrink ||
      arenaWarning;

  String get label => '+$turnsAhead';
}
