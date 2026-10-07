import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/game_colors.dart';
import 'widgets/action_button.dart';
import 'widgets/modal_scaffold.dart';

/// End of run panel: score summary, restart and the Second Chance offer.
class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({
    required this.controller,
    required this.onMainMenu,
    super.key,
  });

  final GameController controller;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final state = controller.state;
        final canRewind = controller.canUseSecondChance;
        final depth = controller.secondChanceDepth;

        return ModalScaffold(
          title: 'GAME OVER',
          accent: GameColors.dangerText,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ModalStatRow(
                label: 'SCORE',
                value: '${state.score}',
                valueColor: GameColors.accent,
              ),
              ModalStatRow(
                label: 'LEVEL REACHED',
                value: '${controller.levelReached}',
                valueColor: GameColors.exitBright,
              ),
              ModalStatRow(
                label: 'BEST SCORE',
                value: '${controller.bestScore}',
                valueColor: GameColors.success,
              ),
              ModalStatRow(
                label: 'BEST LEVEL',
                value: '${controller.bestLevel}',
                valueColor: GameColors.success,
              ),
              if (controller.lastRunWasPersonalBest) ...[
                const SizedBox(height: 8),
                const Text(
                  'NEW BEST!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    color: GameColors.success,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              ActionButton(
                label: 'TRY AGAIN',
                icon: Icons.replay_rounded,
                style: ActionButtonStyle.primary,
                onPressed: () => controller.startNewGame(),
              ),
              const _Hint('Restart from Level 1'),
              const SizedBox(height: 12),
              if (canRewind) ...[
                ActionButton(
                  label: 'SECOND CHANCE',
                  icon: Icons.undo_rounded,
                  busy: controller.isSecondChancePending,
                  onPressed: controller.isSecondChancePending
                      ? null
                      : () => controller.requestSecondChance(),
                ),
                _Hint(
                  depth > 0
                      ? 'Go back $depth ${depth == 1 ? 'turn' : 'turns'}'
                      : 'Go back a turn or two',
                ),
              ] else
                const _Hint('Not enough history yet for a Second Chance.'),
              const SizedBox(height: 12),
              ActionButton(
                label: 'MAIN MENU',
                icon: Icons.home_rounded,
                style: ActionButtonStyle.ghost,
                onPressed: onMainMenu,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Small caption under an action button, so what each button does is obvious
/// without turning the panel into an essay.
class _Hint extends StatelessWidget {
  const _Hint(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 11.5,
          height: 1.35,
          color: GameColors.textSecondary,
        ),
      ),
    );
  }
}
