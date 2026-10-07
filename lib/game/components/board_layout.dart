import 'dart:math' as math;
import 'dart:ui' show Offset, Rect;

import '../models/tile_position.dart';

/// Maps grid coordinates to pixels.
///
/// Everything is derived from the size the `GameWidget` actually received, so
/// the arena always fits the free space between the HUD and the controls - on a
/// phone, a tablet, or a resized desktop window.
class BoardLayout {
  BoardLayout({
    required this.canvasWidth,
    required this.canvasHeight,
    required this.columns,
    required this.rows,
    this.topInset = 0,
    this.bottomInset = 0,
    this.horizontalPadding = 10,
    this.maxCellSize = 84,
    this.minCellSize = 8,
  }) {
    final availableWidth = math.max(0, canvasWidth - horizontalPadding * 2);
    final availableHeight = math.max(0, canvasHeight - topInset - bottomInset);

    final rawCell = math.min(availableWidth / columns, availableHeight / rows);
    cellSize = rawCell.isFinite && rawCell > 0
        ? rawCell.clamp(minCellSize, maxCellSize)
        : minCellSize;

    boardWidth = cellSize * columns;
    boardHeight = cellSize * rows;

    originX = (canvasWidth - boardWidth) / 2;
    originY = topInset + (availableHeight - boardHeight) / 2;
  }

  final double canvasWidth;
  final double canvasHeight;

  final int columns;
  final int rows;

  /// Space reserved by the HUD at the top of the canvas.
  final double topInset;

  /// Space reserved by the preview strip and the controls at the bottom.
  final double bottomInset;

  final double horizontalPadding;
  final double maxCellSize;
  final double minCellSize;

  /// Edge length of one grid cell in logical pixels.
  late final double cellSize;

  late final double boardWidth;
  late final double boardHeight;

  /// Top-left corner of the board in canvas coordinates.
  late final double originX;
  late final double originY;

  /// Cell rectangle in *board local* coordinates (0,0 = board top-left).
  Rect rectFor(int column, int row) =>
      Rect.fromLTWH(column * cellSize, row * cellSize, cellSize, cellSize);

  Rect rectForTile(TilePosition position) => rectFor(position.x, position.y);

  /// Centre of a cell in board local coordinates.
  Offset centerOf(TilePosition position) =>
      Offset((position.x + 0.5) * cellSize, (position.y + 0.5) * cellSize);

  /// Which cell a board local point falls into.
  TilePosition? tileAt(Offset local) {
    final column = (local.dx / cellSize).floor();
    final row = (local.dy / cellSize).floor();
    if (column < 0 || row < 0 || column >= columns || row >= rows) {
      return null;
    }
    return TilePosition(column, row);
  }
}
