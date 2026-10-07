import 'package:flutter/material.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_theme.dart';

/// Visual weight of an [ActionButton].
enum ActionButtonStyle {
  /// Filled with the accent colour - the recommended action.
  primary,

  /// Outlined but still prominent.
  secondary,

  /// Quiet, text-only.
  ghost,
}

/// Rounded arcade button used by the menu and the modal overlays.
class ActionButton extends StatelessWidget {
  const ActionButton({
    required this.label,
    required this.onPressed,
    this.style = ActionButtonStyle.secondary,
    this.icon,
    this.busy = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final ActionButtonStyle style;
  final IconData? icon;

  /// Shows a spinner instead of the icon while an async reward is pending.
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;

    final Color background;
    final Color foreground;
    switch (style) {
      case ActionButtonStyle.primary:
        background = GameColors.accent;
        foreground = GameColors.background;
      case ActionButtonStyle.secondary:
        background = GameColors.surfaceHigh;
        foreground = GameColors.textPrimary;
      case ActionButtonStyle.ghost:
        background = Colors.transparent;
        foreground = GameColors.textSecondary;
    }

    final radius = BorderRadius.circular(14);

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          canRequestFocus: false,
          onTap: enabled ? onPressed : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: style == ActionButtonStyle.secondary
                  ? Border.all(color: GameColors.surfaceBorder)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(foreground),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 18, color: foreground),
                if (busy || icon != null) const SizedBox(width: 10),
                // Flexible so a long label shrinks instead of overflowing the
                // button, however narrow the card gets.
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GameTheme.button.copyWith(color: foreground),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
