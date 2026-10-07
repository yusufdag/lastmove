import '../models/future_turn_preview.dart';
import '../models/game_rules.dart';
import '../models/game_state.dart';
import '../models/player_action.dart';
import 'turn_system.dart';

/// Looks a few turns into the future *without touching the real game*.
///
/// The preview clones the state and then plays out "what if I did nothing" for
/// each upcoming turn. Because the hazard generator reacts to the player's
/// moves, the preview shifts the moment the player actually moves - which is
/// exactly the "every move changes what comes next" feeling the game is about.
///
/// Only aggregates are reported (how many dangers, warnings, ...), never the
/// exact cells, so the player still has to make real decisions.
class FuturePreviewSystem {
  const FuturePreviewSystem({this.turnsAhead = GameRules.previewTurns});

  final int turnsAhead;

  List<FutureTurnPreview> analyze(GameState state, TurnSystem turnSystem) {
    if (!state.status.isRunning) {
      return const <FutureTurnPreview>[];
    }

    final simulation = state.copy();
    final result = <FutureTurnPreview>[];

    for (var step = 1; step <= turnsAhead; step++) {
      final event = turnSystem.advance(simulation, PlayerAction.wait);
      if (!event.accepted) {
        break;
      }
      result.add(
        FutureTurnPreview(
          turnsAhead: step,
          dangers: event.dangersActivated,
          warnings: event.warningsCreated,
          movingBlockMoves: event.movingBlockMoves,
          arenaShrink: event.arenaShrink,
          arenaWarning: event.arenaWarning,
        ),
      );
      if (event.died) {
        // Standing still would already be lethal; nothing further to show.
        break;
      }
    }

    return result;
  }
}
