/// Central place for the numbers that define Last Move's rules.
///
/// Level specific tuning lives in `LevelConfig` / `LevelSystem`; this file only
/// holds values that are the same for every level of every run.
class GameRules {
  const GameRules._();

  // --- Scoring ---------------------------------------------------------------
  /// Points awarded for every turn the player survives.
  static const int scorePerTurn = 10;

  /// Completion bonus, multiplied by the level number, so finishing a level is
  /// always worth more than a few idle turns.
  static const int scorePerLevel = 100;

  // --- Hazard generator ------------------------------------------------------
  /// How many of the player's most recent actions the generator looks at when
  /// it decides where the next telegraph should appear.
  static const int recentMoveMemory = 3;

  /// How many turns ahead the future preview analyses.
  static const int previewTurns = 3;

  // --- Level flow ------------------------------------------------------------
  /// How long "LEVEL COMPLETE" stays up before the next level starts. Short on
  /// purpose: the flow should feel like "one more level", not a results screen.
  static const Duration levelCompleteDuration = Duration(milliseconds: 1100);

  /// How long the "LEVEL n" intro card stays up.
  static const Duration levelIntroDuration = Duration(milliseconds: 1200);

  /// How long the "LAST MOVE!" call stays up once the exit opens.
  static const Duration exitOpenCallDuration = Duration(milliseconds: 1600);

  /// How long a one off teaching nudge stays up on the very first run.
  static const Duration hintDuration = Duration(milliseconds: 2100);

  // --- Second Chance ---------------------------------------------------------
  /// How many full frames of history are kept around.
  static const int historyFrames = 8;

  /// How many turns Second Chance rewinds - inside the current level only.
  static const int secondChanceRewindTurns = 3;
}
