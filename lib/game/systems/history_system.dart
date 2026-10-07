import '../models/game_rules.dart';
import '../models/game_snapshot.dart';

/// Keeps the last few complete turns around so Second Chance can genuinely
/// rewind the world instead of faking it.
class HistorySystem {
  HistorySystem({this.capacity = GameRules.historyFrames});

  /// How many frames are kept. The newest frame is the "now" state.
  final int capacity;

  final List<GameSnapshot> _frames = <GameSnapshot>[];

  int get length => _frames.length;

  /// The frame describing the current turn.
  GameSnapshot? get current => _frames.isEmpty ? null : _frames.last;

  /// `true` when at least one earlier frame exists.
  bool get canRewind => _frames.length > 1;

  /// Clears the timeline and starts again from [initial].
  void reset(GameSnapshot initial) {
    _frames
      ..clear()
      ..add(initial);
  }

  /// Appends the frame produced by the turn that just finished.
  void push(GameSnapshot snapshot) {
    _frames.add(snapshot);
    while (_frames.length > capacity) {
      _frames.removeAt(0);
    }
  }

  /// How many turns [rewind] would actually travel back right now.
  int rewindDepth([int requested = GameRules.secondChanceRewindTurns]) {
    if (_frames.length <= 1) {
      return 0;
    }
    final target = _frames[_targetIndex(requested)];
    return _frames.last.turn - target.turn;
  }

  /// Returns the frame [requested] turns back and drops every frame newer than
  /// it, because the run branches off from that moment.
  GameSnapshot? rewind([int requested = GameRules.secondChanceRewindTurns]) {
    if (_frames.length <= 1) {
      return null;
    }
    final index = _targetIndex(requested);
    final snapshot = _frames[index];
    _frames.removeRange(index + 1, _frames.length);
    return snapshot;
  }

  int _targetIndex(int requested) {
    final wanted = requested < 1 ? 1 : requested;
    final index = _frames.length - 1 - wanted;
    return index < 0 ? 0 : index;
  }
}
