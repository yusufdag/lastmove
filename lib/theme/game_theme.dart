import 'package:flutter/material.dart';

import 'game_colors.dart';

/// Material theme for the whole app. Kept intentionally small: the arcade look
/// is defined by [GameColors] plus a handful of shared text styles.
class GameTheme {
  const GameTheme._();

  static const ColorScheme _scheme = ColorScheme.dark(
    primary: GameColors.accent,
    onPrimary: GameColors.background,
    secondary: GameColors.warning,
    onSecondary: GameColors.background,
    surface: GameColors.surface,
    onSurface: GameColors.textPrimary,
    error: GameColors.danger,
    onError: GameColors.textPrimary,
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: _scheme,
    scaffoldBackgroundColor: GameColors.background,
    textTheme: Typography.whiteMountainView.apply(
      bodyColor: GameColors.textPrimary,
      displayColor: GameColors.textPrimary,
    ),
  );

  /// Small uppercase captions such as `SCORE` or `TURN`.
  static const TextStyle label = TextStyle(
    fontSize: 10,
    height: 1.1,
    letterSpacing: 1.6,
    fontWeight: FontWeight.w700,
    color: GameColors.textSecondary,
  );

  /// Numeric readouts in the HUD.
  static const TextStyle value = TextStyle(
    fontSize: 20,
    height: 1.1,
    fontWeight: FontWeight.w800,
    color: GameColors.textPrimary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 30,
    height: 1.05,
    fontWeight: FontWeight.w900,
    letterSpacing: 6,
    color: GameColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.2,
  );
}
