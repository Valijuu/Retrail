/// Ascent and descent of a ride from its recorded altitudes (#97, ADR 0002).
///
/// Two steps remove GPS noise: a trailing running median over the last
/// [ElevationAccumulator.windowSize] altitudes drops spikes, then a change only
/// counts once the smoothed altitude is [ElevationAccumulator.hysteresisMetres]
/// away from the last counted level. Pure Dart, units are metres.
library;

/// Total climb and drop of a ride in metres, both never negative.
class ElevationGain {
  const ElevationGain({required this.ascent, required this.descent});

  /// The gain of [altitudes] in one pass, or null when fewer than two of them
  /// are usable (non-null): a ride without altitude data has no elevation.
  /// Gives exactly the totals of feeding the list to an [ElevationAccumulator].
  static ElevationGain? of(Iterable<double?> altitudes) {
    final accumulator = ElevationAccumulator();
    altitudes.forEach(accumulator.add);
    return accumulator.gain;
  }

  final double ascent;
  final double descent;
}

/// Feeds altitudes one at a time and exposes the running [ElevationGain].
class ElevationAccumulator {
  /// Samples in the trailing median.
  static const windowSize = 5;

  /// Smallest smoothed change, in metres, that counts.
  static const hysteresisMetres = 3.0;

  final List<double> _window = [];
  double? _level;
  double _ascent = 0;
  double _descent = 0;
  int _usable = 0;

  /// The running totals, or null until two usable altitudes were added.
  ElevationGain? get gain =>
      _usable < 2 ? null : ElevationGain(ascent: _ascent, descent: _descent);

  /// Adds the next altitude; a null one is skipped.
  void add(double? altitude) {
    if (altitude == null) return;
    _usable++;
    _window.add(altitude);
    if (_window.length > windowSize) _window.removeAt(0);

    final smoothed = _median(_window);
    final level = _level;
    if (level == null) {
      _level = smoothed;
      return;
    }
    final change = smoothed - level;
    if (change.abs() < hysteresisMetres) return;
    if (change > 0) {
      _ascent += change;
    } else {
      _descent -= change;
    }
    _level = smoothed;
  }

  // The upper median for an even count, so a 2-sample window follows a real
  // step instead of averaging it away.
  static double _median(List<double> samples) {
    final sorted = [...samples]..sort();
    return sorted[sorted.length ~/ 2];
  }
}
