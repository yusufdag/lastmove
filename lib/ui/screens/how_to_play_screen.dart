import 'package:flutter/material.dart';

import '../../theme/game_colors.dart';
import '../../theme/game_theme.dart';
import '../tile_legend.dart';

/// The full rules screen, reachable from the main menu at any time.
///
/// Mobile first: it is a single vertical scroll, never a fixed layout, so it
/// cannot overflow at any screen size. Kept deliberately short - goal first, then
/// movement, then what each tile does, then the meta buttons.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  /// Route helper so the menu does not have to know about MaterialPageRoute.
  static Route<void> route() =>
      MaterialPageRoute<void>(builder: (context) => const HowToPlayScreen());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GameColors.background,
      body: SafeArea(
        child: Column(
          children: [
            const _Header(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Section(
                          title: 'GOAL',
                          lines: <String>[
                            'Survive until the exit opens.',
                            'Reach the Exit Tile to complete the level.',
                          ],
                        ),
                        _Section(
                          title: 'MOVE',
                          lines: <String>[
                            'Use the arrows, WASD or the on-screen pad.',
                            'Every move advances one turn.',
                          ],
                        ),
                        _Section(
                          title: 'WAIT',
                          lines: <String>[
                            'WAIT stays in place for one turn.',
                            'Sometimes waiting is safer than moving.',
                          ],
                        ),
                        _LegendPanel(),
                        _Section(
                          title: 'FUTURE PREVIEW',
                          lines: <String>[
                            '+1, +2 and +3 show what is coming in the next turns.',
                            'Use it to plan your route.',
                          ],
                        ),
                        _Section(
                          title: 'LAST MOVE',
                          lines: <String>[
                            'After surviving long enough, the Exit opens.',
                            'Reach it to complete the level.',
                          ],
                        ),
                        _Section(
                          title: 'LEVELS',
                          lines: <String>[
                            'Every level becomes more difficult.',
                            'Your run continues until you are defeated.',
                          ],
                        ),
                        _Section(
                          title: 'SECOND CHANCE',
                          lines: <String>[
                            'After Game Over, Second Chance rewinds you 3 turns.',
                            'It stays inside the level you died on.',
                            'Ads will be added there later.',
                          ],
                        ),
                        _Section(
                          title: 'TRY AGAIN',
                          lines: <String>[
                            'Try Again starts a completely new run from Level 1.',
                            'Your best score and best level are kept.',
                          ],
                        ),
                        _Section(
                          title: 'CONTROLS',
                          lines: <String>[
                            'WASD or arrows move · SPACE waits',
                            'ESC pauses · R restarts',
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'HOW TO PLAY',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: GameColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            tooltip: 'Close',
            iconSize: 26,
            color: GameColors.textSecondary,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

/// A titled block of one or two short lines.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: GameTheme.label),
          const SizedBox(height: 5),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                line,
                style: const TextStyle(
                  fontSize: 13.5,
                  height: 1.4,
                  color: GameColors.textPrimary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The tile legend, grouped in a panel so the swatches read as one board.
class _LegendPanel extends StatelessWidget {
  const _LegendPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: GameColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: GameColors.surfaceBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('TILES', style: GameTheme.label),
              const SizedBox(height: 14),
              for (final entry in kTileLegend) TileLegendRow(entry: entry),
            ],
          ),
        ),
      ),
    );
  }
}
