import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../theme/game_colors.dart';
import '../last_move_game.dart';
import '../models/game_state.dart';
import '../models/moving_block.dart';
import '../models/tile_position.dart';
import 'board_layout.dart';

/// Paints the entire arena - board, grid, walls, telegraphs, dangers and the
/// shrinking rings - in a single component.
///
/// One component instead of one per cell keeps the render/update tree tiny,
/// which is what keeps the game at 60 FPS on modest phones. The paints are
/// allocated once and only their colours are nudged per frame.
class ArenaComponent extends PositionComponent {
  ArenaComponent({required this.game});

  final LastMoveGame game;

  final Paint _boardPaint = Paint()..color = GameColors.board;
  final Paint _boardBorderPaint = Paint()
    ..color = GameColors.boardBorder
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;
  final Paint _gridPaint = Paint()
    ..color = GameColors.gridLine
    ..strokeWidth = 1;

  final Paint _blockPaint = Paint()..color = GameColors.block;
  final Paint _blockEdgePaint = Paint()
    ..color = GameColors.blockEdge
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.5;

  final Paint _movingBlockPaint = Paint()..color = GameColors.movingBlock;
  final Paint _markerPaint = Paint()..color = GameColors.movingBlockMarker;

  final Paint _warningPaint = Paint()..color = GameColors.warning;
  final Paint _dangerPaint = Paint()..color = GameColors.danger;
  final Paint _shrinkPaint = Paint()..color = GameColors.shrinkDanger;
  final Paint _shrinkWarningPaint = Paint()..color = GameColors.shrinkWarning;
  final Paint _playerCellPaint = Paint()..color = GameColors.playerTrail;

  final Paint _exitPaint = Paint()..color = GameColors.exit;
  final Paint _exitGlowPaint = Paint()..color = GameColors.exit;
  final Paint _exitCorePaint = Paint()..color = GameColors.exitCore;
  final Paint _exitRingPaint = Paint()
    ..color = GameColors.exitBright
    ..style = PaintingStyle.stroke
    ..strokeWidth = 2;

  @override
  void render(Canvas canvas) {
    final layout = game.layout;
    if (layout == null || layout.cellSize <= 0) {
      return;
    }

    final boardRect = Rect.fromLTWH(
      0,
      0,
      layout.boardWidth,
      layout.boardHeight,
    );
    final radius = Radius.circular(math.min(layout.cellSize * 0.22, 18));
    final board = RRect.fromRectAndRadius(boardRect, radius);

    canvas.drawRRect(board, _boardPaint);
    canvas.save();
    canvas.clipRRect(board);

    _paintGridLines(canvas, layout);
    _paintCells(canvas, game.controller.state, layout);

    canvas.restore();
    canvas.drawRRect(board, _boardBorderPaint);
  }

  void _paintGridLines(Canvas canvas, BoardLayout layout) {
    for (var column = 1; column < layout.columns; column++) {
      final x = column * layout.cellSize;
      canvas.drawLine(Offset(x, 0), Offset(x, layout.boardHeight), _gridPaint);
    }
    for (var row = 1; row < layout.rows; row++) {
      final y = row * layout.cellSize;
      canvas.drawLine(Offset(0, y), Offset(layout.boardWidth, y), _gridPaint);
    }
  }

  void _paintCells(Canvas canvas, GameState state, BoardLayout layout) {
    final cell = layout.cellSize;
    final inset = cell * 0.08;
    final radius = Radius.circular(cell * 0.16);
    final pulse = 0.5 + 0.5 * math.sin(game.time * 5.5);
    final flash = game.turnFlash;

    for (var row = 0; row < state.rows; row++) {
      for (var column = 0; column < state.columns; column++) {
        final position = TilePosition(column, row);

        if (state.dangerCells.contains(position)) {
          _paintDanger(canvas, state, position, layout, radius, pulse, flash);
          continue;
        }

        final movingBlock = state.movingBlockAt(position);
        if (movingBlock != null) {
          final rect = layout.rectFor(column, row).deflate(inset);
          final rrect = RRect.fromRectAndRadius(rect, radius);
          canvas.drawRRect(rrect, _movingBlockPaint);
          canvas.drawRRect(rrect.deflate(1.5), _blockEdgePaint);
          _paintDirectionMarker(canvas, rect, movingBlock);
          continue;
        }

        if (state.isStaticBlock(position)) {
          final rect = layout.rectFor(column, row).deflate(inset);
          final rrect = RRect.fromRectAndRadius(rect, radius);
          canvas.drawRRect(rrect, _blockPaint);
          canvas.drawRRect(rrect.deflate(1.5), _blockEdgePaint);
          continue;
        }

        if (state.warningCells.contains(position)) {
          final rect = layout.rectFor(column, row).deflate(inset);
          _warningPaint.color = Color.lerp(
            GameColors.warning,
            GameColors.warningBright,
            pulse,
          )!;
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, radius),
            _warningPaint,
          );
          continue;
        }

        if (state.isShrinkWarning(position)) {
          final rect = layout.rectFor(column, row).deflate(inset);
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, radius),
            _shrinkWarningPaint,
          );
        }
      }
    }

    // A faint marker under the player makes the board easier to read.
    final playerRect = layout.rectForTile(state.player).deflate(inset * 1.7);
    canvas.drawRRect(
      RRect.fromRectAndRadius(playerRect, radius),
      _playerCellPaint,
    );

    // The exit sits on top of everything: it is the one cell the player is
    // looking for, and it can never overlap a hazard, a wall or the shrink.
    final exit = state.exitPosition;
    if (state.exitUnlocked && exit != null) {
      _paintExit(canvas, layout, exit, pulse);
    }
  }

  /// A pulsing emerald portal plus the "it just opened" bloom.
  void _paintExit(
    Canvas canvas,
    BoardLayout layout,
    TilePosition exit,
    double pulse,
  ) {
    final cell = layout.cellSize;
    final rect = layout.rectForTile(exit);
    final radius = Radius.circular(cell * 0.16);
    final flash = game.exitFlash;

    // Glow, growing briefly when the exit first appears.
    final glow = rect.inflate(cell * 0.12 * (0.4 + flash));
    _exitGlowPaint.color = GameColors.exit.withValues(
      alpha: (0.16 + 0.16 * pulse + 0.30 * flash).clamp(0.0, 0.75),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(glow, Radius.circular(cell * 0.28)),
      _exitGlowPaint,
    );

    // Tile.
    final tile = rect.deflate(cell * 0.08);
    _exitPaint.color = Color.lerp(
      GameColors.exit,
      GameColors.exitBright,
      pulse * 0.55,
    )!;
    canvas.drawRRect(RRect.fromRectAndRadius(tile, radius), _exitPaint);

    // Doorway: a dark arch cut into the tile with a bright ring around it, which
    // reads as "way out" even at a 30 px cell.
    final core = Rect.fromCenter(
      center: tile.center,
      width: cell * 0.44,
      height: cell * 0.52,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(core, Radius.circular(cell * 0.14)),
      _exitCorePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(core, Radius.circular(cell * 0.14)),
      _exitRingPaint,
    );
  }

  void _paintDanger(
    Canvas canvas,
    GameState state,
    TilePosition position,
    BoardLayout layout,
    Radius radius,
    double pulse,
    double flash,
  ) {
    final rect = layout.rectForTile(position).deflate(layout.cellSize * 0.08);

    if (state.isShrinkLethal(position)) {
      canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), _shrinkPaint);
      return;
    }

    // Freshly activated dangers briefly bloom: the "it just fired" animation,
    // without ever holding up a turn.
    final bloom = rect.inflate(layout.cellSize * 0.06 * flash);
    _dangerPaint.color = Color.lerp(
      GameColors.danger,
      GameColors.dangerBright,
      math.max(pulse * 0.6, flash),
    )!;
    canvas.drawRRect(RRect.fromRectAndRadius(bloom, radius), _dangerPaint);
  }

  void _paintDirectionMarker(Canvas canvas, Rect rect, MovingBlock block) {
    final center = rect.center;
    final size = rect.width * 0.2;
    final path = Path();

    if (block.dx != 0) {
      final direction = block.dx.toDouble();
      path
        ..moveTo(center.dx + direction * size * 0.95, center.dy)
        ..lineTo(center.dx - direction * size * 0.5, center.dy - size * 0.62)
        ..lineTo(center.dx - direction * size * 0.5, center.dy + size * 0.62)
        ..close();
    } else {
      final direction = block.dy.toDouble();
      path
        ..moveTo(center.dx, center.dy + direction * size * 0.95)
        ..lineTo(center.dx - size * 0.62, center.dy - direction * size * 0.5)
        ..lineTo(center.dx + size * 0.62, center.dy - direction * size * 0.5)
        ..close();
    }

    canvas.drawPath(path, _markerPaint);
  }
}
