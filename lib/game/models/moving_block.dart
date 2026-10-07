import 'package:flutter/foundation.dart';

import 'tile_position.dart';

/// A wall that slides across the arena every [period] turns.
///
/// It never kills the player: it only blocks movement (and it refuses to move
/// onto the player), so it creates pressure without feeling unfair.
@immutable
class MovingBlock {
  const MovingBlock({
    required this.position,
    required this.dx,
    required this.dy,
    required this.period,
    required this.nextMoveTurn,
  });

  final TilePosition position;

  /// Current direction. Exactly one of [dx]/[dy] is non-zero.
  final int dx;
  final int dy;

  /// How many turns pass between two steps.
  final int period;

  /// Turn on which this block moves next.
  final int nextMoveTurn;

  MovingBlock copyWith({
    TilePosition? position,
    int? dx,
    int? dy,
    int? period,
    int? nextMoveTurn,
  }) {
    return MovingBlock(
      position: position ?? this.position,
      dx: dx ?? this.dx,
      dy: dy ?? this.dy,
      period: period ?? this.period,
      nextMoveTurn: nextMoveTurn ?? this.nextMoveTurn,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MovingBlock &&
          other.position == position &&
          other.dx == dx &&
          other.dy == dy &&
          other.period == period &&
          other.nextMoveTurn == nextMoveTurn;

  @override
  int get hashCode => Object.hash(position, dx, dy, period, nextMoveTurn);

  @override
  String toString() =>
      'MovingBlock $position dir($dx,$dy) every $period next@$nextMoveTurn';
}
