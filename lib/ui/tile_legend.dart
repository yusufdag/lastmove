import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/game_colors.dart';

/// The six things a cell can be, as far as the player is concerned.
enum TileKind { safe, warning, danger, block, movingBlock, exit }

/// One row of the tile legend, used by HOW TO PLAY and the first run tutorial.
@immutable
class TileLegendEntry {
  const TileLegendEntry({
    required this.kind,
    required this.name,
    required this.description,
  });

  final TileKind kind;
  final String name;
  final String description;
}

/// The legend, in the order a new player should learn it.
const List<TileLegendEntry> kTileLegend = <TileLegendEntry>[
  TileLegendEntry(
    kind: TileKind.safe,
    name: 'SAFE',
    description: 'Safe to stand on.',
  ),
  TileLegendEntry(
    kind: TileKind.warning,
    name: 'WARNING',
    description: 'Will become dangerous soon.',
  ),
  TileLegendEntry(
    kind: TileKind.danger,
    name: 'DANGER',
    description: 'Avoid this tile.',
  ),
  TileLegendEntry(
    kind: TileKind.block,
    name: 'BLOCK',
    description: 'Cannot be entered.',
  ),
  TileLegendEntry(
    kind: TileKind.movingBlock,
    name: 'MOVING BLOCK',
    description: 'Moves in the arrow direction.',
  ),
  TileLegendEntry(
    kind: TileKind.exit,
    name: 'EXIT',
    description: 'Reach this tile to finish the level.',
  ),
];

TileLegendEntry tileLegendFor(TileKind kind) =>
    kTileLegend.firstWhere((entry) => entry.kind == kind);

/// A miniature of the real arena tile.
///
/// Drawn with the same colours and the same shape language as the board itself
/// (`ArenaComponent`), so the legend can never drift out of sync with what the
/// player sees in game. Nothing here invents a colour: everything comes from
/// [GameColors].
class TileSwatch extends StatelessWidget {
  const TileSwatch({required this.kind, this.size = 36, super.key});

  final TileKind kind;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _TileSwatchPainter(kind)),
    );
  }
}

class _TileSwatchPainter extends CustomPainter {
  _TileSwatchPainter(this.kind);

  final TileKind kind;

  /// The same proportions the arena uses for its cells.
  static const double _inset = 0.08;
  static const double _radius = 0.16;

  @override
  void paint(Canvas canvas, Size size) {
    final cell = math.min(size.width, size.height);
    if (cell <= 0) {
      return;
    }

    final rect = Offset.zero & Size(cell, cell);
    final radius = Radius.circular(cell * _radius);
    final tile = rect.deflate(cell * _inset);
    final rrect = RRect.fromRectAndRadius(tile, radius);

    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    switch (kind) {
      case TileKind.safe:
        fill.color = GameColors.board;
        canvas.drawRRect(rrect, fill);
        edge.color = GameColors.gridLine;
        canvas.drawRRect(rrect, edge);

      case TileKind.warning:
        fill.color = Color.lerp(
          GameColors.warning,
          GameColors.warningBright,
          0.45,
        )!;
        canvas.drawRRect(rrect, fill);

      case TileKind.danger:
        fill.color = Color.lerp(
          GameColors.danger,
          GameColors.dangerBright,
          0.35,
        )!;
        canvas.drawRRect(rrect, fill);

      case TileKind.block:
        fill.color = GameColors.block;
        canvas.drawRRect(rrect, fill);
        edge.color = GameColors.blockEdge;
        canvas.drawRRect(rrect.deflate(1.5), edge);

      case TileKind.movingBlock:
        fill.color = GameColors.movingBlock;
        canvas.drawRRect(rrect, fill);
        edge.color = GameColors.blockEdge;
        canvas.drawRRect(rrect.deflate(1.5), edge);
        _paintArrow(canvas, tile);

      case TileKind.exit:
        _paintExit(canvas, tile, cell, radius);
    }
  }

  /// The same right-pointing chevron the arena draws on sliding walls.
  void _paintArrow(Canvas canvas, Rect tile) {
    final center = tile.center;
    final size = tile.width * 0.2;
    final marker = Paint()..color = GameColors.movingBlockMarker;

    final path = Path()
      ..moveTo(center.dx + size * 0.95, center.dy)
      ..lineTo(center.dx - size * 0.5, center.dy - size * 0.62)
      ..lineTo(center.dx - size * 0.5, center.dy + size * 0.62)
      ..close();
    canvas.drawPath(path, marker);
  }

  void _paintExit(Canvas canvas, Rect tile, double cell, Radius radius) {
    final fill = Paint();
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = GameColors.exitBright;

    // Glow.
    fill.color = GameColors.exit.withValues(alpha: 0.3);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        tile.inflate(cell * 0.05),
        Radius.circular(cell * 0.28),
      ),
      fill,
    );

    // Tile.
    fill.color = Color.lerp(GameColors.exit, GameColors.exitBright, 0.2)!;
    canvas.drawRRect(RRect.fromRectAndRadius(tile, radius), fill);

    // Doorway.
    final core = Rect.fromCenter(
      center: tile.center,
      width: cell * 0.44,
      height: cell * 0.52,
    );
    final coreRrect = RRect.fromRectAndRadius(
      core,
      Radius.circular(cell * 0.14),
    );
    fill.color = GameColors.exitCore;
    canvas.drawRRect(coreRrect, fill);
    canvas.drawRRect(coreRrect, edge);
  }

  @override
  bool shouldRepaint(_TileSwatchPainter oldDelegate) =>
      oldDelegate.kind != kind;
}

/// `swatch + name + description` row used by both teaching surfaces.
class TileLegendRow extends StatelessWidget {
  const TileLegendRow({required this.entry, super.key});

  final TileLegendEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TileSwatch(kind: entry.kind),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    color: GameColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  entry.description,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: GameColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
