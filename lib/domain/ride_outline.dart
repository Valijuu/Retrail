import 'dart:math' as math;

import 'distance_calculator.dart';
import 'geo_constants.dart';
import 'heading.dart' show LatLng;

/// The box around an outline's points, in degrees.
typedef OutlineBounds = ({
  double south,
  double west,
  double north,
  double east,
});

/// The small stored geometry of one ride (#96, ADR 0001): its points
/// simplified, encoded as a polyline and boxed.
class RideOutline {
  const RideOutline(this.points);

  final List<LatLng> points;

  /// A point within this of the line between its kept neighbours is dropped.
  static const double toleranceM = 5;

  /// An outline never has more points than this.
  static const int maxPoints = 500;

  /// Fewer points than this make no line.
  static const _minPointsForLine = 2;

  /// How much the tolerance grows each time the result still has too many
  /// points.
  static const _toleranceGrowthFactor = 2;

  /// Polyline coordinates are whole numbers of 1e-5 degrees (5 decimals).
  static const _precision = 1e5;

  static const _chunkBits = 5;
  static const _chunkMask = 0x1f;
  static const _continuationBit = 0x20;
  static const _charOffset = 63;

  /// Polyline values are zig-zag encoded: shifted left by this many bits,
  /// with the lowest bit flagging a negative value.
  static const _signShift = 1;
  static const _negativeFlag = 1;

  /// The ride's points reduced to at most [maxPoints], keeping the shape
  /// within a tolerance that starts at [toleranceM].
  static RideOutline simplify(
    List<LatLng> points, {
    DistanceCalculator distance = const HaversineDistanceCalculator(),
  }) {
    if (points.isEmpty) return const RideOutline([]);
    // A ride that recorded a single point never moved: the point twice, so it
    // can be drawn as a dot and found on the map (#136).
    if (points.length < _minPointsForLine) {
      return RideOutline([points.first, points.first]);
    }
    final importance = _splitImportance(points, distance);
    var tolerance = toleranceM;
    while (true) {
      final kept = [
        for (var i = 0; i < points.length; i++)
          // The endpoints stay at any tolerance, also an infinite one.
          if (i == 0 || i == points.length - 1 || importance[i] > tolerance)
            points[i],
      ];
      if (kept.length <= maxPoints) return RideOutline(kept);
      tolerance *= _toleranceGrowthFactor;
    }
  }

  /// The standard encoded polyline of [points] with 5 decimal places.
  String encode() {
    final out = StringBuffer();
    var lastLat = 0, lastLng = 0;
    for (final p in points) {
      final lat = (p.lat * _precision).round();
      final lng = (p.lng * _precision).round();
      _encodeValue(lat - lastLat, out);
      _encodeValue(lng - lastLng, out);
      lastLat = lat;
      lastLng = lng;
    }
    return out.toString();
  }

  /// The outline [encode] wrote as [encoded].
  static RideOutline decode(String encoded) {
    final points = <LatLng>[];
    var index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      final (latDelta, afterLat) = _decodeValue(encoded, index);
      final (lngDelta, afterLng) = _decodeValue(encoded, afterLat);
      lat += latDelta;
      lng += lngDelta;
      index = afterLng;
      points.add((lat: lat / _precision, lng: lng / _precision));
    }
    return RideOutline(points);
  }

  /// The box around all points, or null for an empty outline.
  OutlineBounds? get bounds {
    if (points.isEmpty) return null;
    var south = points.first.lat, north = south;
    var west = points.first.lng, east = west;
    for (final p in points) {
      south = math.min(south, p.lat);
      north = math.max(north, p.lat);
      west = math.min(west, p.lng);
      east = math.max(east, p.lng);
    }
    return (south: south, west: west, north: north, east: east);
  }

  static void _encodeValue(int value, StringBuffer out) {
    var v = value < 0 ? ~(value << _signShift) : value << _signShift;
    while (v >= _continuationBit) {
      out.writeCharCode(((_continuationBit | (v & _chunkMask)) + _charOffset));
      v >>= _chunkBits;
    }
    out.writeCharCode(v + _charOffset);
  }

  static (int, int) _decodeValue(String s, int index) {
    var result = 0, shift = 0, byte = 0;
    do {
      byte = s.codeUnitAt(index++) - _charOffset;
      result |= (byte & _chunkMask) << shift;
      shift += _chunkBits;
    } while (byte >= _continuationBit);
    final value = (result & _negativeFlag) != 0
        ? ~(result >> _signShift)
        : result >> _signShift;
    return (value, index);
  }

  /// For every point, the largest tolerance below which Douglas-Peucker
  /// keeps it (#99): a split's own distance, capped by the split it lies
  /// under, since a range is only split while its parent was. Endpoints get
  /// none: [simplify] keeps them anyway. One pass at [toleranceM]; the explicit stack keeps the
  /// call-stack depth constant (the stack itself may hold many pending ranges).
  static List<double> _splitImportance(
    List<LatLng> points,
    DistanceCalculator distance,
  ) {
    final importance = List<double>.filled(points.length, 0);
    final ranges = <_SplitRange>[
      (first: 0, last: points.length - 1, cap: double.infinity),
    ];
    while (ranges.isNotEmpty) {
      final (:first, :last, :cap) = ranges.removeLast();
      final split = _farthestPoint(points, first, last, distance);
      if (split == null) continue;
      final (:index, distanceM: farthestM) = split;
      final own = math.min(farthestM, cap);
      importance[index] = own;
      ranges
        ..add((first: index, last: last, cap: own))
        ..add((first: first, last: index, cap: own));
    }
    return importance;
  }

  /// The point strictly between [first] and [last] farthest from the line
  /// between them, if it lies beyond [toleranceM]. On equal distances the
  /// first one wins.
  static _Split? _farthestPoint(
    List<LatLng> points,
    int first,
    int last,
    DistanceCalculator distance,
  ) {
    _Split? farthest;
    var farthestM = toleranceM;
    for (var i = first + 1; i < last; i++) {
      final d = segmentDistanceM(
        points[i],
        points[first],
        points[last],
        distance,
      );
      if (d > farthestM) {
        farthest = (index: i, distanceM: d);
        farthestM = d;
      }
    }
    return farthest;
  }
}

/// A stretch of a track still to be split, with the importance of the split
/// it lies under.
typedef _SplitRange = ({int first, int last, double cap});

/// A point that splits a range, with its distance from the range's line.
typedef _Split = ({int index, double distanceM});

const _degreesPerHalfTurn = 180;
const _degreesPerTurn = 360;

/// The longitude of the prime meridian, the reference for wrapping into range.
const _primeMeridianLng = 0.0;

/// [lng] moved by whole turns so it lies within half a turn of [reference],
/// so the way from [reference] to it is the short arc, also across ±180 (#100).
/// A non-finite [lng] or [reference] is returned as [lng] (#140).
double unwrapLongitude(double lng, double reference) {
  final delta = lng - reference;
  // Infinity or NaN has no short arc, and a loop would never end on it.
  if (!delta.isFinite) return lng;
  var turned = delta.remainder(_degreesPerTurn);
  if (turned > _degreesPerHalfTurn) turned -= _degreesPerTurn;
  if (turned < -_degreesPerHalfTurn) turned += _degreesPerTurn;
  return reference + turned;
}

/// Whether [lng], or the same longitude a whole turn east or west, lies
/// between [west] and [east], so a box test also accepts points across ±180
/// (#100).
bool withinLongitudes(double lng, double west, double east) {
  for (final shift in const [0, -_degreesPerTurn, _degreesPerTurn]) {
    final shifted = lng + shift;
    if (shifted >= west && shifted <= east) return true;
  }
  return false;
}

/// [lng] moved by whole turns into `-180` to `180`.
double normaliseLongitude(double lng) {
  if (lng >= -_degreesPerHalfTurn && lng <= _degreesPerHalfTurn) return lng;
  return unwrapLongitude(lng, _primeMeridianLng);
}

/// Distance in metres from [p] to the nearest point of the segment a→b,
/// measured with [distance]. The foot of the perpendicular is found in a
/// local equirectangular frame (longitude scaled by cos(latitude)) around
/// [a], with the longitudes of [b] and [p] unwrapped around it, so a segment
/// across ±180 takes the short arc (#100).
double segmentDistanceM(
  LatLng p,
  LatLng a,
  LatLng b,
  DistanceCalculator distance,
) {
  final bLng = unwrapLongitude(b.lng, a.lng);
  final pLng = unwrapLongitude(p.lng, a.lng);
  final k = math.cos(a.lat * radiansPerDegree);
  final bx = (bLng - a.lng) * k, by = b.lat - a.lat;
  final px = (pLng - a.lng) * k, py = p.lat - a.lat;
  final dd = bx * bx + by * by;
  final t = dd == 0 ? 0.0 : ((px * bx + py * by) / dd).clamp(0.0, 1.0);
  final q = (
    lat: a.lat + (b.lat - a.lat) * t,
    lng: normaliseLongitude(a.lng + (bLng - a.lng) * t),
  );
  return distance.distanceBetween(p.lat, p.lng, q.lat, q.lng);
}
