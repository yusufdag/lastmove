/// Layout constants for the Flutter overlays.
///
/// The Flame board reserves exactly these heights (plus the system insets), so
/// the arena always sits in the free space between the HUD and the controls.
class UiMetrics {
  const UiMetrics._();

  /// Height of the HUD bar, excluding the status bar inset.
  static const double hudHeight = 104;

  /// Height of the `NEXT / +1 / +2 / +3` strip.
  static const double previewHeight = 68;

  /// Height of the touch control pad.
  static const double controlsHeight = 176;

  /// Total space the bottom block takes away from the arena.
  static const double bottomReserve = previewHeight + controlsHeight;

  static const double screenPadding = 12;

  static const double previewCardWidth = 86;
  static const double previewCardHeight = 58;

  static const double controlButtonSize = 52;
  static const double controlGap = 5;
  static const double waitButtonSize = 96;
}
