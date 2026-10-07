import 'package:flutter/material.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_theme.dart';

/// Full screen dim plus an animated card, shared by the pause and game over
/// overlays.
///
/// The card fades and scales in so the end of a run lands with a bit of weight,
/// but it is a plain widget: it never blocks or delays the game loop.
class ModalScaffold extends StatelessWidget {
  const ModalScaffold({
    required this.title,
    required this.child,
    this.accent,
    super.key,
  });

  final String title;
  final Widget child;

  /// Colour used for the title and the card border.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final highlight = accent ?? GameColors.textPrimary;

    return ColoredBox(
      color: GameColors.background.withValues(alpha: 0.78),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            builder: (context, value, panel) {
              return Opacity(
                opacity: value.clamp(0, 1),
                child: Transform.scale(scale: 0.9 + 0.1 * value, child: panel),
              );
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GameColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color:
                        accent?.withValues(alpha: 0.45) ??
                        GameColors.surfaceBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: GameTheme.title.copyWith(
                          fontSize: 22,
                          letterSpacing: 4,
                          color: highlight,
                        ),
                      ),
                      const SizedBox(height: 18),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `label / value` pair used inside the modal cards.
class ModalStatRow extends StatelessWidget {
  const ModalStatRow({
    required this.label,
    required this.value,
    this.valueColor,
    super.key,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(label, style: GameTheme.label),
          const Spacer(),
          Text(
            value,
            style: GameTheme.value.copyWith(
              fontSize: 18,
              color: valueColor ?? GameColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
