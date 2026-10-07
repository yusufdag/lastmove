import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'models/future_turn_preview.dart';
import 'models/game_rules.dart';
import 'models/game_state.dart';
import 'models/game_status.dart';
import 'models/level_config.dart';
import 'models/player_action.dart';
import 'models/tile_position.dart';
import 'services/reward_service.dart';
import 'services/score_service.dart';
import 'services/tutorial_service.dart';
import 'systems/future_preview_system.dart';
import 'systems/history_system.dart';
import 'systems/level_system.dart';
import 'systems/turn_system.dart';

/// Which kind of call-out the level banner is showing.
enum LevelBannerKind {
  /// "LEVEL 4" right after a level starts.
  levelStart,

  /// "LEVEL COMPLETE" while the next level loads in.
  levelComplete,

  /// "LAST MOVE!" the moment the exit opens.
  lastMove,

  /// A one off teaching nudge on the very first run.
  warningHint,
}

/// A short, timed call-out drawn over the board.
///
/// The text is prepared here so the widget stays dumb; only the colours depend on
/// [kind].
@immutable
class LevelBanner {
  const LevelBanner({required this.kind, required this.title, this.subtitle});

  final LevelBannerKind kind;
  final String title;
  final String? subtitle;
}

/// Owns a whole session: state, systems, services and the signals the UI listens
/// to.
///
/// It is a [ChangeNotifier] so the Flutter widgets (HUD, preview strip, overlays)
/// rebuild when a turn resolves, while the Flame layer only ever *reads* the
/// state to draw the arena. Nothing in this file imports Flame.
///
/// A run is an endless chain of levels: finishing one keeps the score and starts
/// the next, harder one. Only death (or TRY AGAIN) ends it.
class GameController extends ChangeNotifier {
  GameController({
    ScoreService? scoreService,
    TutorialService? tutorialService,
    RewardService? rewardService,
    int? seed,
    LevelSystem levelSystem = const LevelSystem(),
    TurnSystem? turnSystem,
    FuturePreviewSystem previewSystem = const FuturePreviewSystem(),
  }) : _scoreService = scoreService ?? ScoreService(),
       _tutorialService = tutorialService ?? TutorialService(),
       _rewardService = rewardService ?? const MockRewardService(),
       _levels = levelSystem,
       _turnSystem = turnSystem ?? TurnSystem(levels: levelSystem),
       _previewSystem = previewSystem,
       _seedOverride = seed {
    _state = GameState(seed: _resolveSeed(), config: _levels.configFor(1));
    _history.reset(_state.toSnapshot());
    _refreshPreview();
    _banner = _levelStartBanner(_state.config);
    _bannerTimer = Timer(GameRules.levelIntroDuration, _clearBanner);
  }

  static final math.Random _seedRandom = math.Random();

  final ScoreService _scoreService;
  final TutorialService _tutorialService;
  final RewardService _rewardService;
  final LevelSystem _levels;
  final TurnSystem _turnSystem;
  final FuturePreviewSystem _previewSystem;
  final HistorySystem _history = HistorySystem();

  /// When set, every run uses this exact seed. Tests rely on it.
  final int? _seedOverride;

  late GameState _state;
  List<FutureTurnPreview> _preview = const <FutureTurnPreview>[];
  int _bestScore = 0;
  int _bestLevel = 0;
  bool _secondChancePending = false;
  int _lastRewindTurns = 0;
  bool _lastRunWasBest = false;
  bool _disposed = false;

  /// Index of the tutorial card being shown, or `null` when it is not running.
  int? _tutorialStep;

  /// Whether the first run tutorial has already been seen (or skipped).
  bool _tutorialSeen = false;

  /// `true` for a player who has never seen the tutorial: their very first run
  /// gets one extra nudge the first time a warning appears, and nothing after.
  bool _showRunHints = false;
  bool _warningHintShown = false;

  LevelBanner? _banner;
  Timer? _bannerTimer;
  Timer? _levelTimer;

  // --- Read-only view of the session -----------------------------------------

  GameState get state => _state;
  GameStatus get status => _state.status;
  LevelConfig get levelConfig => _state.config;

  /// Turns survived across the whole run.
  int get turn => _state.turn;
  int get score => _state.score;

  /// 1-based level the player is on right now.
  int get currentLevel => _state.currentLevel;

  /// Turns survived inside the current level.
  int get levelTurn => _state.levelTurn;

  /// Turns the current level asks the player to survive.
  int get requiredSurvivalTurns => _state.requiredSurvivalTurns;

  /// Turns left before the exit opens (0 once it is open).
  int get turnsUntilExit => _state.turnsUntilExit;

  /// How far through the level's survival phase the player is, 0..1.
  double get levelProgress => _state.levelProgress;

  bool get exitUnlocked => _state.exitUnlocked;
  TilePosition? get exitPosition => _state.exitPosition;

  /// The level the player died on (or is playing) - what GAME OVER reports.
  int get levelReached => _state.currentLevel;

  int get bestScore => _bestScore;
  int get bestLevel => _bestLevel;

  int get seed => _state.seed;
  int get columns => _state.columns;
  int get rows => _state.rows;

  /// The level banner to draw right now, or `null`.
  LevelBanner? get banner => _banner;

  /// `NEXT / +1 / +2 / +3` cards shown above the controls.
  List<FutureTurnPreview> get preview => _preview;

  bool get isSecondChancePending => _secondChancePending;

  /// How many turns the last Second Chance actually rewound.
  int get lastRewindTurns => _lastRewindTurns;

  /// `true` when the run that just ended beat the stored best score.
  bool get lastRunWasPersonalBest => _lastRunWasBest;

  /// `true` while there is enough history to rewind a few turns.
  bool get canUseSecondChance => _history.canRewind;

  /// How far back Second Chance would take the player right now.
  int get secondChanceDepth =>
      _history.rewindDepth(GameRules.secondChanceRewindTurns);

  int get historyLength => _history.length;

  /// `true` while the first run tutorial is on screen.
  bool get isTutorialActive => _tutorialStep != null;

  /// Index of the tutorial card being shown, or `null` when it is not running.
  int? get tutorialStep => _tutorialStep;

  /// Whether the player has already been through (or skipped) the tutorial.
  bool get hasSeenTutorial => _tutorialSeen;

  /// Short line shown by the debug banner in debug builds only.
  String get debugSummary =>
      'seed ${_state.seed}  L${_state.currentLevel} '
      '(${_state.columns}x${_state.rows} ${_state.config.modifier.name})  '
      'turn ${_state.levelTurn}/${_state.requiredSurvivalTurns}  '
      'hazards ${_state.hazards.length}  walls ${_state.blocks.length}';

  // --- Session control -------------------------------------------------------

  /// Loads the records and the tutorial flag from disk.
  Future<void> loadProgress() async {
    await _scoreService.loadBest();
    await _tutorialService.load();
    _bestScore = _scoreService.cachedBestScore;
    _bestLevel = _scoreService.cachedBestLevel;
    _tutorialSeen = _tutorialService.hasSeen;
    _safeNotify();
  }

  /// Shows the first run tutorial from the top.
  ///
  /// While it is running the board is frozen: [perform] is a no-op and keyboard
  /// input is ignored, but the status stays `playing` so no other overlay
  /// (pause) gets involved.
  void startTutorial() {
    _tutorialStep = 0;
    _cancelBanner();
    _safeNotify();
  }

  /// Moves to the next tutorial card, finishing when [stepCount] is reached.
  ///
  /// The count comes from the widget that renders the cards, so the controller
  /// never has to know the tutorial's content.
  void advanceTutorial(int stepCount) {
    final current = _tutorialStep;
    if (current == null) {
      return;
    }
    final next = current + 1;
    if (next >= stepCount) {
      finishTutorial();
      return;
    }
    _tutorialStep = next;
    _safeNotify();
  }

  /// Leaves the tutorial early. Counts as seen, exactly like finishing it.
  void skipTutorial() => finishTutorial();

  /// Ends the tutorial and remembers that it has been shown.
  void finishTutorial() {
    if (_tutorialStep == null) {
      return;
    }
    _tutorialStep = null;
    _tutorialSeen = true;
    unawaited(_tutorialService.markSeen());
    // Hand the player over with the level intro, so the goal is on screen the
    // moment the tutorial closes.
    _showBanner(
      _levelStartBanner(_state.config),
      GameRules.levelIntroDuration,
      notify: false,
    );
    _safeNotify();
  }

  /// Starts a fresh run at level 1 with a score of 0.
  ///
  /// Used by PLAY, TRY AGAIN and RESTART. The stored best score and best level
  /// are never touched by this.
  void startNewGame({int? seed}) {
    _cancelTimers();
    _state = GameState(
      seed: seed ?? _resolveSeed(),
      config: _levels.configFor(1),
    );
    _history.reset(_state.toSnapshot());
    _lastRewindTurns = 0;
    _lastRunWasBest = false;
    _secondChancePending = false;
    // A brand new player gets one contextual nudge during their first run;
    // everyone else gets silence.
    _showRunHints = !_tutorialSeen;
    _warningHintShown = false;
    _refreshPreview();
    _showBanner(
      _levelStartBanner(_state.config),
      GameRules.levelIntroDuration,
      notify: false,
    );
    _safeNotify();
  }

  /// Applies one player action and advances the world one turn.
  ///
  /// Returns `false` when nothing happened (blocked move, paused, game over or a
  /// level transition in progress).
  bool perform(PlayerAction action) {
    if (!_state.status.isRunning || isTutorialActive) {
      return false;
    }

    final event = _turnSystem.advance(_state, action);
    if (!event.accepted) {
      return false;
    }

    // The move landed on the exit: the level is done, so there is nothing to
    // record for a rewind - the timeline starts over on the next level.
    if (event.levelCompleted) {
      _handleLevelComplete(event.levelBonus);
      return true;
    }

    _history.push(_state.toSnapshot());
    _refreshPreview();

    // Very first run only: one nudge the first time a warning appears, then
    // never again. Deliberately before the exit call so "LAST MOVE!" wins if
    // both happen on the same turn.
    if (event.warningsCreated > 0 && _showRunHints && !_warningHintShown) {
      _warningHintShown = true;
      _showBanner(_warningHintBanner(), GameRules.hintDuration, notify: false);
    }

    if (event.exitOpened) {
      _showBanner(
        _lastMoveBanner(),
        GameRules.exitOpenCallDuration,
        notify: false,
      );
    }

    if (_state.status.isOver) {
      _recordBest();
    }

    _safeNotify();
    return true;
  }

  /// Steps from the completed level into the next one.
  ///
  /// Normally driven by the transition timer; public so tests can run the
  /// transition without waiting for wall clock time.
  void advanceToNextLevel() {
    if (!_state.status.isLevelComplete) {
      return;
    }
    _levelTimer?.cancel();
    _levelTimer = null;
    _beginLevel(_state.currentLevel + 1);
  }

  void pause() {
    if (_state.status.isRunning && !isTutorialActive) {
      _state.status = GameStatus.paused;
      _safeNotify();
    }
  }

  void resume() {
    if (_state.status == GameStatus.paused) {
      _state.status = GameStatus.playing;
      _safeNotify();
    }
  }

  /// Pause/resume toggle used by the pause button and the Escape key.
  void togglePause() {
    if (_state.status == GameStatus.paused) {
      resume();
    } else {
      pause();
    }
  }

  /// Asks [RewardService] for a second chance and, if granted, rewinds the world
  /// [GameRules.secondChanceRewindTurns] turns.
  ///
  /// The rewind always lands inside the level the player died on: the history
  /// buffer is restarted at every level, so this can never drag the player back
  /// into an earlier level. This is also the hook a
  /// "watch ad -> continue" flow will use later.
  Future<bool> requestSecondChance() async {
    if (_secondChancePending || !_state.status.isOver) {
      return false;
    }

    _secondChancePending = true;
    _safeNotify();

    final granted = await _rewardService.requestSecondChance();
    _secondChancePending = false;

    if (!granted) {
      _safeNotify();
      return false;
    }

    final depth = _history.rewindDepth(GameRules.secondChanceRewindTurns);
    final snapshot = _history.rewind(GameRules.secondChanceRewindTurns);
    if (snapshot == null) {
      _safeNotify();
      return false;
    }

    _state = GameState.fromSnapshot(snapshot);
    _lastRewindTurns = depth;
    _cancelBanner();
    _refreshPreview();
    _safeNotify();
    return true;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelTimers();
    super.dispose();
  }

  // --- Level flow ------------------------------------------------------------

  void _beginLevel(int level) {
    final config = _levels.configFor(level);
    _state.beginLevel(config);
    // Second Chance only ever rewinds inside the level the player dies on, so the
    // buffer starts fresh here.
    _history.reset(_state.toSnapshot());
    _refreshPreview();
    _showBanner(
      _levelStartBanner(config),
      GameRules.levelIntroDuration,
      notify: false,
    );
    _safeNotify();
  }

  void _handleLevelComplete(int bonus) {
    _levelTimer?.cancel();
    // Nothing to preview while the transition plays: `analyze` returns empty for
    // any status that is not `playing`.
    _refreshPreview();
    _showBanner(
      LevelBanner(
        kind: LevelBannerKind.levelComplete,
        title: 'LEVEL COMPLETE',
        subtitle: 'LEVEL ${_state.currentLevel}   +$bonus',
      ),
      GameRules.levelCompleteDuration,
      notify: false,
    );
    _levelTimer = Timer(GameRules.levelCompleteDuration, advanceToNextLevel);
    _safeNotify();
  }

  LevelBanner _levelStartBanner(LevelConfig config) => LevelBanner(
    kind: LevelBannerKind.levelStart,
    title: 'LEVEL ${config.level}',
    subtitle:
        '${config.modifier.label}   SURVIVE ${config.requiredSurvivalTurns} TURNS',
  );

  LevelBanner _lastMoveBanner() => const LevelBanner(
    kind: LevelBannerKind.lastMove,
    title: 'LAST MOVE!',
    subtitle: 'Reach the Exit.',
  );

  /// The single teaching nudge a brand new player gets on their first run.
  LevelBanner _warningHintBanner() => const LevelBanner(
    kind: LevelBannerKind.warningHint,
    title: 'WARNING!',
    subtitle: 'Move away before it activates.',
  );

  // --- Internals -------------------------------------------------------------

  void _refreshPreview() {
    _preview = _previewSystem.analyze(_state, _turnSystem);
  }

  /// Fire and forget persistence of a new best score / best level.
  void _recordBest() {
    var changed = false;

    if (_state.score > _bestScore) {
      _bestScore = _state.score;
      _lastRunWasBest = true;
      changed = true;
      unawaited(_scoreService.submitScore(_bestScore));
    }
    if (_state.currentLevel > _bestLevel) {
      _bestLevel = _state.currentLevel;
      changed = true;
      unawaited(_scoreService.submitLevel(_bestLevel));
    }

    if (changed) {
      _safeNotify();
    }
  }

  void _showBanner(
    LevelBanner banner,
    Duration duration, {
    bool notify = true,
  }) {
    _banner = banner;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(duration, _clearBanner);
    if (notify) {
      _safeNotify();
    }
  }

  void _clearBanner() {
    _bannerTimer = null;
    _banner = null;
    _safeNotify();
  }

  void _cancelBanner() {
    _bannerTimer?.cancel();
    _bannerTimer = null;
    _banner = null;
  }

  void _cancelTimers() {
    _cancelBanner();
    _levelTimer?.cancel();
    _levelTimer = null;
  }

  int _resolveSeed() => _seedOverride ?? _seedRandom.nextInt(0x7FFFFFFF);

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }
}
