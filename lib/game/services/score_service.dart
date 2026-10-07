import 'package:shared_preferences/shared_preferences.dart';

/// Persists the two numbers the game carries between runs: the best score and
/// the furthest level reached.
///
/// SharedPreferences is used *only* for this, and nothing else in the game
/// depends on it - if you prefer them purely in memory, pass a different
/// implementation of this class to `GameController`.
class ScoreService {
  static const String _bestScoreKey = 'last_move.best_score';
  static const String _bestLevelKey = 'last_move.best_level';

  int _cachedBestScore = 0;
  int _cachedBestLevel = 0;
  bool _loaded = false;

  /// The best score known right now (0 until [loadBest] finishes).
  int get cachedBestScore => _cachedBestScore;

  /// The highest level number reached so far (0 until [loadBest] finishes).
  int get cachedBestLevel => _cachedBestLevel;

  Future<void> loadBest() async {
    final preferences = await SharedPreferences.getInstance();
    _cachedBestScore = preferences.getInt(_bestScoreKey) ?? 0;
    _cachedBestLevel = preferences.getInt(_bestLevelKey) ?? 0;
    _loaded = true;
  }

  /// Stores [score] when it beats the stored best.
  ///
  /// Returns `true` when a new best score was written.
  Future<bool> submitScore(int score) async {
    if (!_loaded) {
      await loadBest();
    }
    if (score <= _cachedBestScore) {
      return false;
    }
    _cachedBestScore = score;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_bestScoreKey, score);
    return true;
  }

  /// Stores [level] when it beats the stored best level.
  ///
  /// Returns `true` when a new best level was written.
  Future<bool> submitLevel(int level) async {
    if (!_loaded) {
      await loadBest();
    }
    if (level <= _cachedBestLevel) {
      return false;
    }
    _cachedBestLevel = level;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_bestLevelKey, level);
    return true;
  }
}
