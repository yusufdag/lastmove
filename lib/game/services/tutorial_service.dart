import 'package:shared_preferences/shared_preferences.dart';

/// Remembers whether the player has already been through the first run tutorial.
///
/// SharedPreferences is used *only* for this one flag, exactly like
/// [ScoreService] uses it for the records - if you would rather keep it in
/// memory, pass a different implementation of this class to `GameController`.
class TutorialService {
  /// The stored key. Public so tests can assert on it directly.
  static const String hasSeenTutorialKey = 'last_move.has_seen_tutorial';

  bool _seen = false;
  bool _loaded = false;

  /// Whether the tutorial has been seen (false until [load] finishes, so a brand
  /// new player is always taught rather than skipped).
  bool get hasSeen => _seen;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _seen = preferences.getBool(hasSeenTutorialKey) ?? false;
    _loaded = true;
  }

  /// Marks the tutorial as seen. Called when it is finished *or* skipped.
  Future<void> markSeen() async {
    _seen = true;
    if (!_loaded) {
      // Nothing to read back; writing is enough from here on.
      _loaded = true;
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(hasSeenTutorialKey, true);
  }
}
