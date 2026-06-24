import 'dart:math';

/// Picks greeting indices with a shuffled-queue strategy (ported from the
/// original Home): every greeting is shown once per cycle before reshuffling,
/// and a reshuffle avoids repeating the just-shown greeting across the cycle
/// boundary. [Random] is injectable for deterministic tests.
class GreetingSelector {
  GreetingSelector({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<int> _queue = [];
  int _last = -1;

  /// Returns the next greeting index for a list of [size] greetings.
  int next(int size) {
    if (size <= 0) return 0;
    if (_queue.isEmpty) {
      final shuffled = List<int>.generate(size, (i) => i)..shuffle(_random);
      if (shuffled.length > 1 && shuffled.first == _last) {
        final swap = shuffled.first;
        shuffled[0] = shuffled.last;
        shuffled[shuffled.length - 1] = swap;
      }
      _queue.addAll(shuffled);
    }
    final next = _queue.removeAt(0);
    _last = next;
    return next;
  }
}
