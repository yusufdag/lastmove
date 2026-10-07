import 'dart:async';

import 'package:flutter/material.dart';

import '../../game/game_controller.dart';
import '../../theme/game_colors.dart';
import '../../theme/game_theme.dart';
import '../widgets/action_button.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';

/// Entry screen: title, slogan, the PLAY button and a short rules recap.
class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  late final GameController _controller;

  @override
  void initState() {
    super.initState();
    // One controller owns the session for as long as the menu lives, so the best
    // score survives going in and out of a run.
    _controller = GameController();
    unawaited(_controller.loadProgress());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _play() {
    // Starting a run notifies the controller, so it happens here in the tap
    // handler rather than while widgets are being built.
    _controller.startNewGame();
    // A brand new player is walked through the basics before the board goes live.
    if (!_controller.hasSeenTutorial) {
      _controller.startTutorial();
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => GameScreen(controller: _controller),
      ),
    );
  }

  void _openHowToPlay() {
    Navigator.of(context).push(HowToPlayScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'LAST MOVE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: GameColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Every move changes what comes next.\n'
                    'Survive, open the exit, make your last move.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: GameColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (context, _) => _BestRunPanel(
                      bestScore: _controller.bestScore,
                      bestLevel: _controller.bestLevel,
                    ),
                  ),
                  const SizedBox(height: 24),
                  ActionButton(
                    label: 'PLAY',
                    icon: Icons.play_arrow_rounded,
                    style: ActionButtonStyle.primary,
                    onPressed: _play,
                  ),
                  const SizedBox(height: 12),
                  ActionButton(
                    label: 'HOW TO PLAY',
                    icon: Icons.menu_book_rounded,
                    onPressed: _openHowToPlay,
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Prototype build â€” core mechanics only.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: GameColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BestRunPanel extends StatelessWidget {
  const _BestRunPanel({required this.bestScore, required this.bestLevel});

  final int bestScore;
  final int bestLevel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GameColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: GameColors.surfaceBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('BEST SCORE', style: GameTheme.label),
                  const SizedBox(height: 4),
                  Text(
                    '$bestScore',
                    style: GameTheme.value.copyWith(
                      fontSize: 26,
                      color: GameColors.success,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('BEST LEVEL', style: GameTheme.label),
                  const SizedBox(height: 4),
                  Text(
                    '$bestLevel',
                    style: GameTheme.value.copyWith(
                      fontSize: 26,
                      color: GameColors.exitBright,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
