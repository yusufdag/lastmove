import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/game_colors.dart';
import '../theme/game_theme.dart';
import 'tile_legend.dart';
import 'widgets/action_button.dart';

/// One card of the first run tutorial.
@immutable
class TutorialStep {
  const TutorialStep({
    required this.title,
    required this.body,
    this.tile,
    this.icon,
  });

  final String title;
  final String body;

  /// A miniature of the real board tile, when the step is about a tile.
  final TileKind? tile;

  /// A plain icon for the steps that are about a concept instead of a tile.
  final IconData? icon;
}

/// The five things a new player has to know, in order.
const List<TutorialStep> kTutorialSteps = <TutorialStep>[
  TutorialStep(
    title: 'MOVE',
    body: 'Every move advances one turn.',
    icon: Icons.videogame_asset_rounded,
  ),
  TutorialStep(
    title: 'WARNING',
    body: 'Leave warning tiles before they become dangerous.',
    tile: TileKind.warning,
  ),
  TutorialStep(
    title: 'PREVIEW',
    body: 'Check the next turns before you move.',
    icon: Icons.remove_red_eye_rounded,
  ),
  TutorialStep(
    title: 'LAST MOVE',
    body: 'Survive until the Exit opens.',
    icon: Icons.hourglass_bottom_rounded,
  ),
  TutorialStep(
    title: 'EXIT',
    body: 'Reach the Exit to complete the level.',
    tile: TileKind.exit,
  ),
];

/// The first run tutorial.
///
/// It is an overlay that collapses to nothing when it is not running, so the
/// live board stays visible behind a dim and nothing has to be added to or
/// removed from the overlay stack. While it is up the controller refuses input,
/// so the world cannot move underneath the player.
class TutorialOverlay extends StatelessWidget {
  const TutorialOverlay({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final index = controller.tutorialStep;
        if (index == null || index < 0 || index >= kTutorialSteps.length) {
          return const SizedBox.shrink();
        }
        return _TutorialPanel(
          step: kTutorialSteps[index],
          index: index,
          total: kTutorialSteps.length,
          onNext: () => controller.advanceTutorial(kTutorialSteps.length),
          onSkip: controller.skipTutorial,
        );
      },
    );
  }
}

class _TutorialPanel extends StatelessWidget {
  const _TutorialPanel({
    required this.step,
    required this.index,
    required this.total,
    required this.onNext,
    required this.onSkip,
  });

  final TutorialStep step;
  final int index;
  final int total;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  bool get _isLast => index == total - 1;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: GameColors.background.withValues(alpha: 0.82),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: TweenAnimationBuilder<double>(
            key: ValueKey<int>(index),
            tween: Tween<double>(begin: 0, end: 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            builder: (context, value, card) => Opacity(
              opacity: value.clamp(0, 1),
              child: Transform.translate(
                offset: Offset(0, 12 * (1 - value)),
                child: card,
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: GameColors.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: GameColors.accent.withValues(alpha: 0.45),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'STEP ${index + 1} / $total',
                            style: GameTheme.label,
                          ),
                          const Spacer(),
                          for (var i = 0; i < total; i++)
                            Container(
                              width: 6,
                              height: 6,
                              margin: EdgeInsets.only(left: i == 0 ? 0 : 5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= index
                                    ? GameColors.accent
                                    : GameColors.surfaceBorder,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _StepGraphic(step: step),
                      const SizedBox(height: 18),
                      Text(
                        step.title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 3.5,
                          color: GameColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        step.body,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: GameColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: ActionButton(
                              label: 'SKIP',
                              style: ActionButtonStyle.ghost,
                              onPressed: onSkip,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ActionButton(
                              label: _isLast ? 'START' : 'NEXT',
                              style: ActionButtonStyle.primary,
                              onPressed: onNext,
                            ),
                          ),
                        ],
                      ),
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

/// The visual anchor of a step: a real tile miniature, or an icon.
class _StepGraphic extends StatelessWidget {
  const _StepGraphic({required this.step});

  final TutorialStep step;

  @override
  Widget build(BuildContext context) {
    final tile = step.tile;
    if (tile != null) {
      return TileSwatch(kind: tile, size: 64);
    }

    return Container(
      width: 64,
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: GameColors.surfaceHigh,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: GameColors.surfaceBorder),
      ),
      child: Icon(step.icon, size: 30, color: GameColors.accent),
    );
  }
}
