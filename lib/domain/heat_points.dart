import 'distance_calculator.dart';
import 'heading.dart' show LatLng;
import 'ride_outline.dart';

/// The weighted points the overview heatmap draws, taken along ride
/// outlines (#96). Every point weighs `1`.
class HeatPoints {
  HeatPoints._();

  /// Arc length between two heat points.
  static const double spacingM = 30;

  /// A point of the last segment this close to its end counts as the end
  /// itself, so float noise never adds a second point there.
  static const double _endSnapM = 1e-6;

  /// The fewest points an outline needs to have a length at all.
  static const int _minOutlinePoints = 2;

  /// Points at every [spacingM] of arc length along [outline], starting on
  /// its first point and ending on its last.
  static List<LatLng> along(
    RideOutline outline, {
    DistanceCalculator distance = const HaversineDistanceCalculator(),
  }) {
    final points = outline.points;
    if (points.length < _minOutlinePoints) return const [];
    final out = <LatLng>[points.first];
    var untilNext = spacingM;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1], to = points[i];
      final length = distance.distanceBetween(
        from.lat,
        from.lng,
        to.lat,
        to.lng,
      );
      var covered = 0.0;
      while (covered + untilNext <= length) {
        covered += untilNext;
        untilNext = spacingM;
        out.add(_between(from, to, covered / length));
      }
      untilNext -= length - covered;
    }
    final sinceLastPoint = spacingM - untilNext;
    if (sinceLastPoint > _endSnapM) out.add(points.last);
    return out;
  }

  /// The point at [fraction] (`0` to `1`) of the straight way from [from]
  /// to [to].
  static LatLng _between(LatLng from, LatLng to, double fraction) => (
    lat: from.lat + (to.lat - from.lat) * fraction,
    lng: from.lng + (to.lng - from.lng) * fraction,
  );
}
