import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../game/game_controller.dart';
import '../../game/last_move_game.dart';
import '../../game/models/game_status.dart';
import '../../game/models/player_action.dart';
import '../../theme/game_colors.dart';
import '../controls_overlay.dart';
import '../future_preview_widget.dart';
import '../game_hud.dart';
import '../game_over_overlay.dart';
import '../level_banner_overlay.dart';
import '../overlay_names.dart';
import '../pause_overlay.dart';
import '../tutorial_overlay.dart';
import '../ui_metrics.dart';

/// The playable screen.
///
/// The `GameWidget` fills the whole screen and every UI element is a Flame
/// overlay on top of it, so the modals can cover the HUD as well. The board
/// itself is told how much vertical space the overlays take, which keeps the
/// arena centred in the free area on any screen size.
class GameScreen extends StatefulWidget {
  const GameScreen({required this.controller, super.key});

  final GameController controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final LastMoveGame _game;

  @override
  void initState() {
    super.initState();
    _game = LastMoveGame(controller: widget.controller);
    HardwareKeyboard.instance.addHandler(_onKeyEvent);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyEvent);
    _game.detachFromController();
    super.dispose();
  }

  void _goToMainMenu() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  /// Android back button: never leave the game straight away.
  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    final controller = widget.controller;
    // During the tutorial, back simply skips it.
    if (controller.isTutorialActive) {
      controller.skipTutorial();
      return;
    }
    final status = controller.status;
    if (status == GameStatus.paused || status.isOver) {
      _goToMainMenu();
      return;
    }
    controller.pause();
  }

  /// Returns `true` when this handler consumed the event.
  bool _onKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) {
      return false;
    }

    final controller = widget.controller;
    final key = event.logicalKey;

    // The tutorial owns input while it is up.
    if (controller.isTutorialActive) {
      return false;
    }

    if (key == LogicalKeyboardKey.keyR) {
      controller.startNewGame();
      return true;
    }
    if (key == LogicalKeyboardKey.escape && !controller.status.isOver) {
      controller.togglePause();
      return true;
    }

    final action = _actionForKey(key);
    if (action == null) {
      return false;
    }
    if (controller.status.isRunning) {
      controller.perform(action);
    }
    return true;
  }

  PlayerAction? _actionForKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.keyW || key == LogicalKeyboardKey.arrowUp) {
      return PlayerAction.up;
    }
    if (key == LogicalKeyboardKey.keyS || key == LogicalKeyboardKey.arrowDown) {
      return PlayerAction.down;
    }
    if (key == LogicalKeyboardKey.keyA || key == LogicalKeyboardKey.arrowLeft) {
      return PlayerAction.left;
    }
    if (key == LogicalKeyboardKey.keyD ||
        key == LogicalKeyboardKey.arrowRight) {
      return PlayerAction.right;
    }
    if (key == LogicalKeyboardKey.space) {
      return PlayerAction.wait;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);

    // Tell the board how much room the overlays need. This is what makes the
    // arena responsive: it is centred inside whatever is left over.
    _game.setPlayAreaInsets(
      top: insets.top + 4 + UiMetrics.hudHeight,
      bottom: insets.bottom + 10 + UiMetrics.bottomReserve,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
        backgroundColor: GameColors.background,
        body: MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.25,
          child: GameWidget<LastMoveGame>(
            game: _game,
            overlayBuilderMap: <String, OverlayWidgetBuilder<LastMoveGame>>{
              OverlayNames.hud: (context, game) =>
                  GameHud(controller: widget.controller),
              OverlayNames.preview: (context, game) =>
                  FuturePreviewWidget(controller: widget.controller),
              OverlayNames.controls: (context, game) =>
                  ControlsOverlay(controller: widget.controller),
              OverlayNames.banner: (context, game) =>
                  LevelBannerOverlay(controller: widget.controller),
              OverlayNames.tutorial: (context, game) =>
                  TutorialOverlay(controller: widget.controller),
              OverlayNames.pause: (context, game) => PauseOverlay(
                controller: widget.controller,
                onMainMenu: _goToMainMenu,
              ),
              OverlayNames.gameOver: (context, game) => GameOverOverlay(
                controller: widget.controller,
                onMainMenu: _goToMainMenu,
              ),
            },
            initialActiveOverlays: const <String>[
              OverlayNames.hud,
              OverlayNames.preview,
              OverlayNames.controls,
              OverlayNames.banner,
              OverlayNames.tutorial,
            ],
          ),
        ),
      ),
    );
  }
}
