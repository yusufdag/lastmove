/// High level state of a session.
///
/// `menu` is intentionally not part of this enum: the main menu is a separate
/// screen, so the game itself only ever needs these states.
enum GameStatus {
  /// The player can act.
  playing,

  /// The player paused the run; nothing advances until it resumes.
  paused,

  /// The player died. The board is frozen until a restart or a Second Chance.
  gameOver,

  /// The player made the last move into the exit. Input is locked while the
  /// level transition plays out.
  levelComplete;

  bool get isRunning => this == GameStatus.playing;
  bool get isOver => this == GameStatus.gameOver;
  bool get isLevelComplete => this == GameStatus.levelComplete;
}
