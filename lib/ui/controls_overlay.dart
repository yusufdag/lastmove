import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/models/player_action.dart';
import '../theme/game_colors.dart';
import '../theme/game_theme.dart';
import 'ui_metrics.dart';

/// Touch controls: a four way pad plus a dedicated WAIT button.
///
/// Shown on desktop too - the mouse works and it keeps one single control
/// solution across every platform. The whole block is wrapped in a [FittedBox]
/// so it shrinks instead of overflowing on small phones.
class ControlsOverlay extends StatelessWidget {
  const ControlsOverlay({required this.controller, super.key});

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
          bottom: bottomInset + 10,
        ),
        child: SizedBox(
          height: UiMetrics.controlsHeight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _DirectionPad(onAction: controller.perform),
                const SizedBox(width: 22),
                _WaitButton(onAction: controller.perform),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DirectionPad extends StatelessWidget {
  const _DirectionPad({required this.onAction});

  final bool Function(PlayerAction action) onAction;

  static const double _button = UiMetrics.controlButtonSize;
  static const double _gap = UiMetrics.controlGap;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(<Widget>[
          const _EmptySlot(),
          _PadButton(
            icon: Icons.keyboard_arrow_up_rounded,
            onTap: () => onAction(PlayerAction.up),
          ),
          const _EmptySlot(),
        ]),
        const SizedBox(height: _gap),
        _row(<Widget>[
          _PadButton(
            icon: Icons.keyboard_arrow_left_rounded,
            onTap: () => onAction(PlayerAction.left),
          ),
          const _EmptySlot(),
          _PadButton(
            icon: Icons.keyboard_arrow_right_rounded,
            onTap: () => onAction(PlayerAction.right),
          ),
        ]),
        const SizedBox(height: _gap),
        _row(<Widget>[
          const _EmptySlot(),
          _PadButton(
            icon: Icons.keyboard_arrow_down_rounded,
            onTap: () => onAction(PlayerAction.down),
          ),
          const _EmptySlot(),
        ]),
      ],
    );
  }

  Widget _row(List<Widget> columns) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < columns.length; i++) ...[
          if (i > 0) const SizedBox(width: _gap),
          columns[i],
        ],
      ],
    );
  }
}

/// Invisible placeholder that keeps the D-pad grid aligned.
class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: _DirectionPad._button,
      height: _DirectionPad._button,
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    return SizedBox(
      width: UiMetrics.controlButtonSize,
      height: UiMetrics.controlButtonSize,
      child: Material(
        color: GameColors.surfaceHigh.withValues(alpha: 0.92),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          canRequestFocus: false,
          onTap: onTap,
          child: Icon(icon, size: 30, color: GameColors.textPrimary),
        ),
      ),
    );
  }
}

class _WaitButton extends StatelessWidget {
  const _WaitButton({required this.onAction});

  final bool Function(PlayerAction action) onAction;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(20);
    return SizedBox(
      width: UiMetrics.waitButtonSize,
      height: UiMetrics.waitButtonSize,
      child: Material(
        color: GameColors.surfaceHigh.withValues(alpha: 0.92),
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          canRequestFocus: false,
          onTap: () => onAction(PlayerAction.wait),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.hourglass_empty_rounded,
                size: 24,
                color: GameColors.accent,
              ),
              const SizedBox(height: 4),
              Text(
                'WAIT',
                style: GameTheme.button.copyWith(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  color: GameColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
