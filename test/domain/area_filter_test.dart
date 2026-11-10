import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/area_filter.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/ride_outline.dart';

const _calc = HaversineDistanceCalculator();

/// Metres per degree of latitude (and of longitude on the equator).
const _metresPerDegree = 111320.0;

/// A point [north] / [east] kilometres from the origin (0, 0).
LatLng _km(double north, double east) =>
    (lat: north * 1000 / _metresPerDegree, lng: east * 1000 / _metresPerDegree);

void main() {
  group('AreaFilter radius', () {
    test('the default radius is 5 km', () {
      expect(AreaFilter(pin: _km(0, 0)).radiusKm, 5);
    });

    test('radius 0 or below is clamped to 1', () {
      expect(AreaFilter(pin: _km(0, 0), radiusKm: 0).radiusKm, 1);
      expect(AreaFilter(pin: _km(0, 0), radiusKm: -3).radiusKm, 1);
    });

    test('radius 80 is clamped to 50', () {
      expect(AreaFilter(pin: _km(0, 0), radiusKm: 80).radiusKm, 50);
    });

    test('two filters with the same pin and radius are equal', () {
      final a = AreaFilter(pin: _km(1, 2), radiusKm: 7);
      final b = AreaFilter(pin: _km(1, 2), radiusKm: 7);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(a.copyWith(radiusKm: 8)));
    });
  });

  group('AreaFilter.matches', () {
    final pin = _km(0, 0);
    AreaFilter filter([double radius = 5]) =>
        AreaFilter(pin: pin, radiusKm: radius);
    bool matches(AreaFilter f, List<LatLng> points) =>
        f.matches(RideOutline(points), distance: _calc);

    test('an outline with fewer than two points never matches', () {
      expect(matches(filter(), const []), isFalse);
      expect(matches(filter(), [pin]), isFalse);
    });

    test('ride crosses the circle: 3 km from the pin at radius 5 matches', () {
      expect(matches(filter(), [_km(3, -10), _km(3, 10)]), isTrue);
    });

    test('ride stays outside: nearest segment 8 km away does not match', () {
      expect(matches(filter(), [_km(8, -10), _km(8, 10)]), isFalse);
    });

    test('a segment passing the circle matches with both ends outside', () {
      expect(matches(filter(), [_km(-20, 1), _km(20, 1)]), isTrue);
    });

    test('an outline that ends exactly 5 km from the pin matches', () {
      final end = _km(5, 0);
      final exact = _calc.distanceBetween(pin.lat, pin.lng, end.lat, end.lng);
      final f = AreaFilter(pin: pin, radiusKm: exact / 1000);
      // radius is clamped to a double; the end sits exactly on the circle.
      expect(matches(f, [_km(5, 20), end]), isTrue);
    });

    test('bounds grown by the radius reject a far outline unmeasured', () {
      final counting = _CountingCalculator();
      final far = RideOutline([_km(100, 0), _km(100, 5)]);
      expect(filter().matches(far, distance: counting), isFalse);
      expect(counting.calls, 0);
    });

    test('the nearest segment distance stays within 1 % at 50 km', () {
      // A segment passing 49.6 km north of the pin matches at 50 km,
      // one passing 50.5 km north does not.
      expect(matches(filter(50), [_km(49.6, -20), _km(49.6, 20)]), isTrue);
      expect(matches(filter(50), [_km(50.5, -20), _km(50.5, 20)]), isFalse);
    });
  });
}

/// Counts how often a distance is measured.
class _CountingCalculator implements DistanceCalculator {
  int calls = 0;

  @override
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) {
    calls++;
    return 0;
  }
}
