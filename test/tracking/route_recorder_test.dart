import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/route_recorder.dart';

/// Positions on a straight line: latitude is metres along it.
class _LineCalc implements DistanceCalculator {
  const _LineCalc();
  @override
  double distanceBetween(double a, double b, double c, double d) =>
      (c - a).abs();
}

const _second = 1000000000;

LocationFix _at(
  double metres,
  int seconds, {
  double? speed,
  double? altitude,
}) => LocationFix(
  latitude: metres,
  longitude: 0,
  accuracy: 5,
  hasSpeed: speed != null,
  speed: speed ?? 0,
  elapsedRealtimeNanos: seconds * _second,
  altitude: altitude,
  altitudeAccuracy: 3,
);

void main() {
  late RouteRecorder route;

  setUp(() => route = RouteRecorder(const _LineCalc()));

  test('starts empty', () {
    expect(route.points, isEmpty);
    expect(route.distanceMetres, 0);
  });

  test('records the first fix as the start, adding no distance', () {
    final first = _at(0, 0);
    expect(route.add(first), [first]);
    expect(route.points, [(lat: 0.0, lng: 0.0)]);
    expect(route.distanceMetres, 0);
  });

  test('adds a segment for real movement: 20 m in 2 s', () {
    route.add(_at(0, 0));
    route.add(_at(20, 2));
    expect(route.points, hasLength(2));
    expect(route.distanceMetres, 20);
  });

  test('returns nothing for a fix the filter drops: 3 m is drift', () {
    route.add(_at(0, 0));
    expect(route.add(_at(3, 1)), isEmpty);
    expect(route.points, hasLength(1));
  });

  test('records held fixes in order once confirmed after a long stop', () {
    route.add(_at(0, 0));
    final held = _at(40, 900, speed: 4);
    expect(route.add(held), isEmpty);
    final confirming = _at(44 + 4, 901, speed: 4);
    expect(route.add(confirming), [held, confirming]);
    expect(route.distanceMetres, 48);
  });

  test('breakSegment: the next fix starts afresh, the gap adds nothing', () {
    route.add(_at(0, 0));
    route.breakSegment();
    route.add(_at(500, 1000));
    expect(route.points, hasLength(2));
    expect(route.distanceMetres, 0);
  });

  test('breakSegment drops held fixes', () {
    route.add(_at(0, 0));
    route.add(_at(40, 900, speed: 4)); // held
    route.breakSegment();
    expect(route.add(_at(48, 901, speed: 4)), hasLength(1));
    expect(route.distanceMetres, 0);
  });

  test('clear starts a new, empty route', () {
    route.add(_at(0, 0));
    route.add(_at(20, 2));
    route.clear();
    expect(route.points, isEmpty);
    expect(route.distanceMetres, 0);
    route.add(_at(500, 3));
    expect(route.distanceMetres, 0); // first point of the new route
  });

  group('elevation (#97)', () {
    test('is none until two recorded fixes carry an altitude', () {
      route.add(_at(0, 0));
      route.add(_at(20, 2));
      expect(route.elevation, isNull);
    });

    test('follows the altitudes of recorded fixes', () {
      route.add(_at(0, 0, altitude: 100));
      route.add(_at(20, 2, altitude: 110));
      route.add(_at(40, 4, altitude: 100));
      expect(route.elevation!.ascent, 10);
      expect(route.elevation!.descent, 10);
    });

    test('ignores the altitude of a fix the filter does not record', () {
      route.add(_at(0, 0, altitude: 100));
      route.add(_at(20, 2, altitude: 100));
      // Stationary by provider speed: not recorded, so its altitude is not used.
      expect(route.add(_at(21, 3, speed: 0.1, altitude: 500)), isEmpty);
      expect(route.elevation!.ascent, 0);
    });

    test('clear starts a new elevation', () {
      route.add(_at(0, 0, altitude: 100));
      route.add(_at(20, 2, altitude: 110));
      route.clear();
      expect(route.elevation, isNull);
    });

    test('a segment break keeps the elevation of the ride', () {
      route.add(_at(0, 0, altitude: 100));
      route.add(_at(20, 2, altitude: 110));
      route.breakSegment();
      expect(route.elevation, isNotNull);
    });
  });
}
