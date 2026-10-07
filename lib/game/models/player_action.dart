import 'tile_position.dart';

/// The single action a player may take in a turn.
///
/// Diagonal movement is intentionally not part of the game.
enum PlayerAction {
  up(0, -1),
  down(0, 1),
  left(-1, 0),
  right(1, 0),
  wait(0, 0);

  const PlayerAction(this.dx, this.dy);

  final int dx;
  final int dy;

  /// Grid delta produced by this action.
  TilePosition get delta => TilePosition(dx, dy);

  /// Waiting is the only action that never needs a free target cell.
  bool get isMovement => this != PlayerAction.wait;
}
