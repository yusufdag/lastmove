import 'dart:math' as math;

import 'package:flame/game.dart';

import '../ui/overlay_names.dart';
import 'components/arena_component.dart';
import 'components/board_layout.dart';
import 'components/player_component.dart';
import 'game_controller.dart';
import 'models/game_status.dart';
import 'models/tile_position.dart';

/// The Flame side of Last Move.
///
/// Its responsibilities are deliberately narrow: turn [GameController] state
/// into pixels. No gameplay rule lives here, and the controller never imports
/// Flame - which is what keeps the two layers cleanly separated.
///
/// The arena is added to `camera.viewport`, i.e. screen space, so board
/// coordinates are plain pixels. That removes every camera/zoom special case and
/// makes the responsive layout a single multiplication.
class LastMoveGame extends FlameGame {
  LastMoveGame({required this.controller}) {
    controller.addListener(_onControllerChanged);
  }

  final GameController controller;

  ArenaComponent? _arena;
  PlayerComponent? _player;
  BoardLayout? _layout;

  double _time = 0;
  double _turnFlash = 0;
  double _exitFlash = 0;
  double _insetTop = 0;
  double _insetBottom = 0;
  Vector2 _canvasSize = Vector2.zero();
  TilePosition _renderedCell = TilePosition.zero;
  TilePosition? _renderedExit;
  int _renderedTurn = 0;
  int _renderedLevel = 1;
  bool _ready = false;

  /// Board geometry for the current canvas size, or `null` before the first
  /// layout pass.
  BoardLayout? get layout => _layout;

  /// Seconds since the game started. Drives the tile pulse animations.
  double get time => _time;

  /// 1 right after a turn resolved, fading to 0. Used for the "it just fired"
  /// bloom on freshly activated dangers.
  double get turnFlash => _turnFlash;

  /// 1 the moment the exit appears, fading to 0. Drives the exit's opening bloom.
  double get exitFlash => _exitFlash;

  /// Space the Flutter UI reserves at the top and bottom of the canvas.
  ///
  /// The arena is centred inside whatever is left, so the board never sits
  /// behind the HUD or the touch controls.
  void setPlayAreaInsets({required double top, required double bottom}) {
    if (top == _insetTop && bottom == _insetBottom) {
      return;
    }
    _insetTop = top;
    _insetBottom = bottom;
    _relayout();
  }

  @override
  Future<void> onLoad() async {
    final arena = ArenaComponent(game: this);
    final player = PlayerComponent();

    arena.add(player);
    // Screen space: board coordinates are pixels, no camera maths involved.
    camera.viewport.add(arena);

    _arena = arena;
    _player = player;
    _renderedCell = controller.state.player;
    _renderedTurn = controller.state.turn;
    _renderedLevel = controller.state.currentLevel;
    _renderedExit = controller.state.exitPosition;

    if (_canvasSize.x <= 0) {
      _canvasSize = size.clone();
    }

    _ready = true;
    _relayout();
    player.popIn();
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    _canvasSize = size.clone();
    _relayout();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _time += dt;
    if (_turnFlash > 0) {
      _turnFlash = math.max(0, _turnFlash - dt);
    }
    if (_exitFlash > 0) {
      _exitFlash = math.max(0, _exitFlash - dt * 0.8);
    }
  }

  @override
  void onRemove() {
    controller.removeListener(_onControllerChanged);
    super.onRemove();
  }

  // --- Layout ----------------------------------------------------------------

  void _relayout() {
    final arena = _arena;
    final player = _player;
    if (!_ready || arena == null || player == null) {
      return;
    }

    final width = _canvasSize.x > 0 ? _canvasSize.x : size.x;
    final height = _canvasSize.y > 0 ? _canvasSize.y : size.y;
    if (width <= 0 || height <= 0) {
      return;
    }

    final layout = BoardLayout(
      canvasWidth: width,
      canvasHeight: height,
      columns: controller.state.columns,
      rows: controller.state.rows,
      topInset: _insetTop,
      bottomInset: _insetBottom,
    );
    _layout = layout;

    arena
      ..size = Vector2(layout.boardWidth, layout.boardHeight)
      ..position = Vector2(layout.originX, layout.originY);

    player.size = Vector2.all(layout.cellSize * 0.62);
    _syncPlayer(immediate: true);
  }

  void _syncPlayer({required bool immediate}) {
    final layout = _layout;
    final player = _player;
    if (layout == null || player == null) {
      return;
    }

    final center = layout.centerOf(controller.state.player);
    final target = Vector2(center.dx, center.dy);
    if (immediate) {
      player.snapTo(target);
    } else {
      player.moveTo(target);
    }
    _renderedCell = controller.state.player;
  }

  /// Reacts to the controller: slides the token and triggers the flash.
  ///
  /// This is the *only* place where Flutter/Flame state and gameplay state meet,
  /// and it never mutates the game.
  void _onControllerChanged() {
    if (!_ready) {
      return;
    }
    final state = controller.state;

    // A new level rebuilds the world - possibly on a differently sized grid - so
    // there is nothing to animate across it.
    final layout = _layout;
    final levelChanged =
        state.currentLevel != _renderedLevel ||
        layout == null ||
        layout.columns != state.columns ||
        layout.rows != state.rows;
    if (levelChanged) {
      _renderedLevel = state.currentLevel;
      _relayout();
      _player?.popIn();
    }

    if (state.turn != _renderedTurn) {
      final rewound = state.turn < _renderedTurn;
      _renderedTurn = state.turn;
      _turnFlash = 0.38;
      if (rewound) {
        // A Second Chance (or a restart) jumped the world backwards; snapping
        // looks far better than sliding across the whole board.
        _syncPlayer(immediate: true);
      }
    }

    if (state.exitPosition != _renderedExit) {
      final justOpened = state.exitPosition != null && _renderedExit == null;
      _renderedExit = state.exitPosition;
      if (justOpened) {
        _exitFlash = 1;
      }
    }

    if (state.player != _renderedCell) {
      final currentLayout = _layout;
      final player = _player;
      if (currentLayout != null && player != null) {
        final center = currentLayout.centerOf(state.player);
        player.moveTo(Vector2(center.dx, center.dy));
      }
      _renderedCell = state.player;
    }

    if (state.status.isOver) {
      _turnFlash = 0.45;
    }

    _syncOverlays();
  }

  /// Shows/hides the modal overlays so they always match the game status.
  ///
  /// Only called from the controller listener, i.e. after `GameWidget` has
  /// registered the overlay builders.
  void _syncOverlays() {
    final paused = controller.status == GameStatus.paused;
    _setOverlay(OverlayNames.pause, paused);

    final over = controller.status.isOver;
    _setOverlay(OverlayNames.gameOver, over);
  }

  void _setOverlay(String name, bool visible) {
    if (visible) {
      if (!overlays.isActive(name)) {
        overlays.add(name);
      }
    } else if (overlays.isActive(name)) {
      overlays.remove(name);
    }
  }

  /// Detaches from the controller.
  ///
  /// Called both from [onRemove] (when Flame tears the game down) and from the
  /// owning widget's `dispose`, so the listener can never outlive the screen.
  void detachFromController() {
    controller.removeListener(_onControllerChanged);
  }
}
