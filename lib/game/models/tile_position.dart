import 'package:flutter/foundation.dart';

/// A discrete coordinate inside the arena grid.
///
/// `x` grows to the right and `y` grows downwards (row index), which matches
/// how the arena is painted on screen.
@immutable
class TilePosition {
  const TilePosition(this.x, this.y);

  static const TilePosition zero = TilePosition(0, 0);

  final int x;
  final int y;

  TilePosition operator +(TilePosition other) =>
      TilePosition(x + other.x, y + other.y);

  TilePosition operator -(TilePosition other) =>
      TilePosition(x - other.x, y - other.y);

  /// Manhattan distance. Used by the hazard generator to describe "how close"
  /// a candidate cell is to the player.
  int manhattanDistanceTo(TilePosition other) =>
      (x - other.x).abs() + (y - other.y).abs();

  @override
  bool operator ==(Object other) =>
      other is TilePosition && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => '($x, $y)';
}
