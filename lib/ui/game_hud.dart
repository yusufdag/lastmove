import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/game_colors.dart';
import '../theme/game_theme.dart';
import 'ui_metrics.dart';

/// Top bar of the game: title, score, turn, best score and the pause button.
class GameHud extends StatelessWidget {
  const GameHud({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(
          top: topInset + 4,
          left: UiMetrics.screenPadding,
          right: UiMetrics.screenPadding,
        ),
        child: SizedBox(
          height: UiMetrics.hudHeight,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'LAST MOVE',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3.5,
                            color: GameColors.textPrimary,
                          ),
                        ),
                      ),
                      _PauseButton(onPressed: controller.togglePause),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          label: 'SCORE',
                          value: '${controller.score}',
                          color: GameColors.accent,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'LEVEL',
                          value: '${controller.currentLevel}',
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: controller.exitUnlocked ? 'EXIT' : 'EXIT IN',
                          value: controller.exitUnlocked
                              ? 'OPEN'
                              : '${controller.turnsUntilExit}',
                          color: controller.exitUnlocked
                              ? GameColors.exitBright
                              : GameColors.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: _Stat(
                          label: 'BEST',
                          value: '${controller.bestScore}',
                          color: GameColors.success,
                        ),
                      ),
                    ],
                  ),
                  if (kDebugMode) ...[
                    const SizedBox(height: 2),
                    Text(
                      controller.debugSummary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 9,
                        color: GameColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GameTheme.label,
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 18,
              height: 1.15,
              fontWeight: FontWeight.w800,
              color: color ?? GameColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(10);
    return SizedBox(
      width: 34,
      height: 34,
      child: Material(
        color: GameColors.surfaceHigh.withValues(alpha: 0.9),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          canRequestFocus: false,
          onTap: onPressed,
          child: const Icon(
            Icons.pause_rounded,
            size: 18,
            color: GameColors.textPrimary,
          ),
        ),
      ),
    );
  }
}
