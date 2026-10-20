import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/ride_stats.dart';
import 'package:retrail/domain/route_row_stats.dart';

RideStats _ride(double metres, int seconds) => RideStats(
  distanceMetres: metres,
  durationMs: seconds * 1000,
  maxSpeedKmh: 30,
  avgSpeedKmh: metres / seconds * 3.6,
);

void main() {
  group('routeRowStats', () {
    test('the original shows its ride — 4600 m, 906 s, 18 km/h, no hint', () {
      final row = routeRowStats(_ride(4600, 906), routeLengthM: 4600);
      expect(row.distanceMetres, 4600);
      expect(row.durationMs, 906000);
      expect(row.avgSpeedKmh, closeTo(18.3, 0.1));
      expect(row.offRouteMetres, isNull);
    });
    test('a follow without a route time shows its ride unchanged', () {
      final row = routeRowStats(
        _ride(7000, 1144),
        routeLengthM: 4600,
        coverage: 1,
      );
      expect(row.distanceMetres, 7000);
      expect(row.durationMs, 1144000);
      expect(row.offRouteMetres, isNull);
    });
    test('a follow shows the route length ridden — 4600 m route at coverage 1 '
        'of a 7000 m ride is 4600 m', () {
      final row = routeRowStats(
        _ride(7000, 1144),
        routeLengthM: 4600,
        coverage: 1,
        routeTimeMs: 773000,
      );
      expect(row.distanceMetres, 4600);
    });
    test('a follow shows its time on the route — 773 s', () {
      final row = routeRowStats(
        _ride(7000, 1144),
        routeLengthM: 4600,
        coverage: 1,
        routeTimeMs: 773000,
      );
      expect(row.durationMs, 773000);
    });
    test(
      'a follow\'s average is over the route — 4600 m in 773 s is 21.4 km/h',
      () {
        final row = routeRowStats(
          _ride(7000, 1144),
          routeLengthM: 4600,
          coverage: 1,
          routeTimeMs: 773000,
        );
        expect(row.avgSpeedKmh, closeTo(21.4, 0.1));
      },
    );
    test(
      'a partial follow counts its share — 4600 m at coverage 0.41 is 1886 m',
      () {
        final row = routeRowStats(
          _ride(1900, 280),
          routeLengthM: 4600,
          coverage: 0.41,
          routeTimeMs: 280000,
        );
        expect(row.distanceMetres, closeTo(1886, 0.5));
      },
    );
    test('the metres off the route are the rest of the ride — 7000 − 4600 is '
        '2400 m', () {
      final row = routeRowStats(
        _ride(7000, 1144),
        routeLengthM: 4600,
        coverage: 1,
        routeTimeMs: 773000,
      );
      expect(row.offRouteMetres, 2400);
    });
    test('under 100 m off the route is GPS noise — no hint', () {
      final row = routeRowStats(
        _ride(4699, 900),
        routeLengthM: 4600,
        coverage: 1,
        routeTimeMs: 880000,
      );
      expect(row.offRouteMetres, isNull);
    });
    test('exactly 100 m off the route is shown', () {
      final row = routeRowStats(
        _ride(4700, 900),
        routeLengthM: 4600,
        coverage: 1,
        routeTimeMs: 880000,
      );
      expect(row.offRouteMetres, 100);
    });
    test('the route part is never longer than the ride — a 4000 m ride on a '
        '4600 m route at coverage 1 is 4000 m, no hint', () {
      final row = routeRowStats(
        _ride(4000, 900),
        routeLengthM: 4600,
        coverage: 1,
        routeTimeMs: 880000,
      );
      expect(row.distanceMetres, 4000);
      expect(row.offRouteMetres, isNull);
    });
    test('a zero route time has no average — 0 km/h', () {
      final row = routeRowStats(
        _ride(4600, 900),
        routeLengthM: 4600,
        coverage: 1,
        routeTimeMs: 0,
      );
      expect(row.avgSpeedKmh, 0);
    });
  });
}
