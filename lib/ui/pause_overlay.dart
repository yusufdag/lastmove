import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/game_colors.dart';
import 'widgets/action_button.dart';
import 'widgets/modal_scaffold.dart';

/// Pause menu shown while the run is suspended.
class PauseOverlay extends StatelessWidget {
  const PauseOverlay({
    required this.controller,
    required this.onMainMenu,
    super.key,
  });

  final GameController controller;
  final VoidCallback onMainMenu;

  @override
  Widget build(BuildContext context) {
    return ModalScaffold(
      title: 'PAUSED',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ActionButton(
            label: 'RESUME',
            icon: Icons.play_arrow_rounded,
            style: ActionButtonStyle.primary,
            onPressed: controller.resume,
          ),
          const SizedBox(height: 10),
          ActionButton(
            label: 'RESTART',
            icon: Icons.refresh_rounded,
            onPressed: () => controller.startNewGame(),
          ),
          const SizedBox(height: 10),
          ActionButton(
            label: 'MAIN MENU',
            icon: Icons.home_rounded,
            style: ActionButtonStyle.ghost,
            onPressed: onMainMenu,
          ),
          const SizedBox(height: 18),
          const Text(
            'WASD or arrows to move  ·  SPACE to wait\n'
            'R to restart  ·  ESC to pause',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: GameColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
