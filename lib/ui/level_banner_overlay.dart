import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../theme/game_colors.dart';

/// Short call-outs that carry the level loop: "LEVEL 4" when a level starts,
/// "LAST MOVE!" the moment the exit opens, and "LEVEL COMPLETE" on the way out.
///
/// It sits over the board but ignores pointer events, so the player can keep
/// playing - and keep running for the exit - while it is on screen. Nothing here
/// ever delays a turn.
class LevelBannerOverlay extends StatelessWidget {
  const LevelBannerOverlay({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: const Alignment(0, -0.38),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final banner = controller.banner;
            if (banner == null) {
              return const SizedBox.shrink();
            }
            // A fresh key per banner instance so every call-out animates in.
            return KeyedSubtree(
              key: ValueKey<LevelBanner>(banner),
              child: _BannerCard(banner: banner),
            );
          },
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({required this.banner});

  final LevelBanner banner;

  @override
  Widget build(BuildContext context) {
    final accent = switch (banner.kind) {
      LevelBannerKind.levelStart => GameColors.accent,
      LevelBannerKind.levelComplete => GameColors.exitBright,
      LevelBannerKind.lastMove => GameColors.exitBright,
      LevelBannerKind.warningHint => GameColors.warning,
    };

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value.clamp(0, 1),
        child: Transform.scale(scale: 0.92 + 0.08 * value, child: child),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: GameColors.background.withValues(alpha: 0.84),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: accent.withValues(alpha: 0.55),
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  banner.title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.5,
                    color: accent,
                  ),
                ),
                if (banner.subtitle != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    banner.subtitle!,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                      color: GameColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
