/// Names of the Flame overlays used by [GameWidget].
///
/// Overlays are pure Flutter widgets drawn on top of the arena, which keeps the
/// presentation layer out of the game logic.
class OverlayNames {
  const OverlayNames._();

  static const String hud = 'hud';
  static const String preview = 'preview';
  static const String controls = 'controls';
  static const String banner = 'banner';
  static const String tutorial = 'tutorial';
  static const String pause = 'pause';
  static const String gameOver = 'game-over';
}
