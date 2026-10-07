/// Tiny deterministic pseudo random generator (xorshift32).
///
/// Why not `dart:math`'s [Random]?
/// * [Random] does not expose its internal state, so a snapshot could not
///   restore the exact stream.
/// * This generator stores its whole state in a single `int`, which makes both
///   game history and the "what happens if I do nothing" preview trivial and
///   exactly reproducible.
class SeededRandom {
  SeededRandom(int seed) : _state = _normalize(seed);

  int _state;

  /// The complete internal state. Safe to store inside a game snapshot.
  int get state => _state;

  set state(int value) => _state = _normalize(value);

  /// An independent generator that continues from the current state.
  SeededRandom copy() => SeededRandom(_state);

  static int _normalize(int seed) {
    // xorshift32 degenerates when the state is zero, so never allow it.
    final masked = seed & 0xFFFFFFFF;
    return masked == 0 ? 0x9E3779B9 : masked;
  }

  int _next() {
    var x = _state;
    x ^= (x << 13) & 0xFFFFFFFF;
    x ^= x >> 17;
    x ^= (x << 5) & 0xFFFFFFFF;
    _state = x & 0xFFFFFFFF;
    return _state;
  }

  /// Uniform double in `[0, 1)`.
  double nextDouble() => _next() / 4294967296.0;

  /// Uniform int in `[0, max)`.
  int nextInt(int max) {
    if (max <= 0) {
      return 0;
    }
    return _next() % max;
  }

  /// `true` with the given [probability] (default: a fair coin flip).
  bool nextBool([double probability = 0.5]) => nextDouble() < probability;
}
