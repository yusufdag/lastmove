import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/components.dart';

import '../../theme/game_colors.dart';

/// The player token.
///
/// Movement is animated *here only*. The gameplay state has already changed by
/// the time the slide starts, so the animation can never delay a turn.
class PlayerComponent extends PositionComponent {
  PlayerComponent() : super(anchor: Anchor.center);

  /// Duration of the hop between two cells.
  static const double slideDuration = 0.11;

  final Paint _glowPaint = Paint()
    ..color = GameColors.playerGlow.withValues(alpha: 0.35);
  final Paint _bodyPaint = Paint()..color = GameColors.player;
  final Paint _highlightPaint = Paint()
    ..color = GameColors.playerHighlight.withValues(alpha: 0.85);

  final Vector2 _from = Vector2.zero();
  final Vector2 _to = Vector2.zero();
  double _progress = 1;
  double _appear = 0;

  /// Jumps straight to [center] (board local coordinates) without animating.
  void snapTo(Vector2 center) {
    position.setFrom(center);
    _from.setFrom(center);
    _to.setFrom(center);
    _progress = 1;
  }

  /// Slides to [center] (board local coordinates).
  void moveTo(Vector2 center) {
    _from.setFrom(position);
    _to.setFrom(center);
    _progress = 0;
  }

  /// Plays the "new run" pop.
  void popIn() => _appear = 0;

  @override
  void update(double dt) {
    super.update(dt);

    if (_progress < 1) {
      _progress = math.min(1, _progress + dt / slideDuration);
      final t = _easeOutCubic(_progress);
      position.setValues(
        _from.x + (_to.x - _from.x) * t,
        _from.y + (_to.y - _from.y) * t,
      );
    }

    _appear = math.min(1, _appear + dt * 4.5);
    final hop = 1 + 0.12 * math.sin(math.pi * _progress);
    final factor = hop * (0.45 + 0.55 * _easeOutCubic(_appear));
    scale.setValues(factor, factor);
  }

  @override
  void render(Canvas canvas) {
    final width = size.x;
    final height = size.y;
    if (width <= 0 || height <= 0) {
      return;
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          -width * 0.24,
          -height * 0.24,
          width * 1.48,
          height * 1.48,
        ),
        Radius.circular(width * 0.74),
      ),
      _glowPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, width, height),
        Radius.circular(width * 0.28),
      ),
      _bodyPaint,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(width * 0.24, height * 0.2, width * 0.3, height * 0.3),
        Radius.circular(width * 0.15),
      ),
      _highlightPaint,
    );
  }

  static double _easeOutCubic(double t) => 1 - math.pow(1 - t, 3).toDouble();
}
