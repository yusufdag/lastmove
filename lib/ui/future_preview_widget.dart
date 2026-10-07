import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/models/future_turn_preview.dart';
import '../theme/game_colors.dart';
import '../theme/game_theme.dart';
import 'ui_metrics.dart';

/// The `NEXT / +1 / +2 / +3` strip.
///
/// It reports categories and counts, never exact cells: enough to plan, not
/// enough to solve the game. The values come straight from the controller's
/// preview, which simulates "what if I did nothing" - so the strip shifts the
/// instant the player moves somewhere else.
class FuturePreviewWidget extends StatelessWidget {
  const FuturePreviewWidget({required this.controller, super.key});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.only(
          left: UiMetrics.screenPadding,
          right: UiMetrics.screenPadding,
          bottom: bottomInset + UiMetrics.controlsHeight,
        ),
        child: SizedBox(
          height: UiMetrics.previewHeight,
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              final previews = controller.preview;
              return FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(right: 10),
                      child: Text('NEXT', style: GameTheme.label),
                    ),
                    for (var index = 0; index < 3; index++)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: _PreviewCard(
                          turnsAhead: index + 1,
                          preview: index < previews.length
                              ? previews[index]
                              : null,
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.turnsAhead, required this.preview});

  final int turnsAhead;
  final FutureTurnPreview? preview;

  @override
  Widget build(BuildContext context) {
    final data = preview;
    final facts = _factsFor(data);

    return Container(
      width: UiMetrics.previewCardWidth,
      decoration: BoxDecoration(
        color: GameColors.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: facts.first.color.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('+$turnsAhead', style: GameTheme.label),
          const SizedBox(height: 2),
          for (final fact in facts.take(2))
            Text(
              fact.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.4,
                color: fact.color,
              ),
            ),
        ],
      ),
    );
  }
}

/// Small coloured facts shown inside a preview card, most urgent first.
List<_PreviewFact> _factsFor(FutureTurnPreview? preview) {
  if (preview == null) {
    return const <_PreviewFact>[_PreviewFact('—', GameColors.textSecondary)];
  }

  final facts = <_PreviewFact>[];
  if (preview.dangers > 0) {
    facts.add(_PreviewFact('${preview.dangers} DANGER', GameColors.dangerText));
  }
  if (preview.warnings > 0) {
    facts.add(_PreviewFact('${preview.warnings} WARN', GameColors.warning));
  }
  if (preview.movingBlockMoves > 0) {
    facts.add(const _PreviewFact('WALL MOVE', GameColors.movingBlockMarker));
  }
  if (preview.arenaShrink) {
    facts.add(const _PreviewFact('SHRINK', GameColors.shrinkWarning));
  } else if (preview.arenaWarning) {
    facts.add(const _PreviewFact('SHRINK SOON', GameColors.shrinkWarning));
  }

  if (facts.isEmpty) {
    facts.add(const _PreviewFact('SAFE', GameColors.success));
  }
  return facts;
}

class _PreviewFact {
  const _PreviewFact(this.text, this.color);

  final String text;
  final Color color;
}
