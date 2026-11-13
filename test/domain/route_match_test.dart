import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/ride_outline.dart' show OutlineBounds;
import 'package:retrail/domain/route_match.dart';

const _metresPerDegreeLat = 111195.0;

/// A straight line along a latitude near Munich from [fromLng] to [toLng],
/// [offsetM] metres north of the base line, with [n] points.
List<LatLng> _line({
  double fromLng = 11.50,
  double toLng = 11.52,
  double offsetM = 0,
  int n = 20,
}) => [
  for (var i = 0; i < n; i++)
    (
      lat: 48.13 + offsetM / _metresPerDegreeLat,
      lng: fromLng + (toLng - fromLng) * i / (n - 1),
    ),
];

OutlineBounds? _boxOf(List<LatLng> points) => points.isEmpty
    ? null
    : (
        south: points.map((p) => p.lat).reduce((a, b) => a < b ? a : b),
        west: points.map((p) => p.lng).reduce((a, b) => a < b ? a : b),
        north: points.map((p) => p.lat).reduce((a, b) => a > b ? a : b),
        east: points.map((p) => p.lng).reduce((a, b) => a > b ? a : b),
      );

RouteMatchEntry _ride(int id, List<LatLng> points, {int? follows}) =>
    RouteMatchEntry(
      rideId: id,
      followedRideId: follows,
      bounds: _boxOf(points),
      points: points,
    );

void main() {
  group('RouteMatch.groups', () {
    test('no entries — an empty map', () {
      expect(RouteMatch.groups(const []), isEmpty);
    });
    test('a single ride keys to its own id', () {
      expect(RouteMatch.groups([_ride(5, _line())]), {5: 5});
    });
    test('ride 7 with an empty outline keys to 7', () {
      expect(RouteMatch.groups([_ride(7, const [])]), {7: 7});
    });
    test('an outline with one point matches no other ride on its spot', () {
      final line = _line();
      expect(
        RouteMatch.groups([
          _ride(1, line),
          _ride(2, [line.first]),
        ]),
        {1: 1, 2: 2},
      );
    });
    test(
      'two rides on the same street 10 m apart share the key of the smaller id',
      () {
        expect(
          RouteMatch.groups([_ride(9, _line(offsetM: 10)), _ride(3, _line())]),
          {3: 3, 9: 3},
        );
      },
    );
    test('rides 121 and 124 on the same line key to 121', () {
      expect(
        RouteMatch.groups([_ride(124, _line(offsetM: 2)), _ride(121, _line())]),
        {121: 121, 124: 121},
      );
    });
    test('two rides on one line in opposite directions share a key', () {
      expect(
        RouteMatch.groups([
          _ride(2, _line()),
          _ride(1, _line(fromLng: 11.52, toLng: 11.50)),
        ]),
        {1: 1, 2: 1},
      );
    });
    test('a point 31 m from the other outline keeps the rides apart', () {
      expect(
        RouteMatch.groups([_ride(1, _line()), _ride(2, _line(offsetM: 31))]),
        {1: 1, 2: 2},
      );
    });
    test('a line 29 m from the other outline still matches', () {
      // 30 m itself is not testable with float degrees; 29 m is the edge.
      expect(
        RouteMatch.groups([_ride(1, _line()), _ride(2, _line(offsetM: 29))]),
        {1: 1, 2: 1},
      );
    });
    test(
      'a ride covering only the first half of another stays in its own group',
      () {
        expect(
          RouteMatch.groups([_ride(1, _line()), _ride(2, _line(toLng: 11.51))]),
          {1: 1, 2: 2},
        );
      },
    );
    test(
      'bounds more than 30 m apart never match and their points are not read',
      () {
        final far = _line(offsetM: 5000);
        final unreadable = RouteMatchEntry(
          rideId: 2,
          bounds: _boxOf(far),
          points: _UnreadablePoints(),
        );
        expect(RouteMatch.groups([_ride(1, _line()), unreadable]), {
          1: 1,
          2: 2,
        });
      },
    );
    test(
      'groups are transitive: A~B and B~C give one key although A and C differ',
      () {
        // 20 m steps: A~B and B~C, but A and C are 40 m apart.
        expect(
          RouteMatch.groups([
            _ride(4, _line()),
            _ride(3, _line(offsetM: 20)),
            _ride(2, _line(offsetM: 40)),
          ]),
          {2: 2, 3: 2, 4: 2},
        );
      },
    );
    test('ride 125 follows 121 on another line: key 121', () {
      expect(
        RouteMatch.groups([
          _ride(121, _line()),
          _ride(125, _line(offsetM: 5000), follows: 121),
        ]),
        {121: 121, 125: 121},
      );
    });
    test('a follow of a ride that is not among the entries stays alone', () {
      expect(RouteMatch.groups([_ride(5, _line(), follows: 99)]), {5: 5});
    });
    test('a follow link and a line match together join three rides', () {
      expect(
        RouteMatch.groups([
          _ride(1, _line()),
          _ride(2, _line(offsetM: 2)),
          _ride(3, _line(offsetM: 5000), follows: 2),
        ]),
        {1: 1, 2: 1, 3: 1},
      );
    });
    test('many rides on one line are matched fast', () {
      // 60 rides with 300 points on one line: rides already in one group
      // are not compared again.
      final entries = [
        for (var id = 1; id <= 60; id++)
          _ride(id, _line(offsetM: id % 5 * 1.0, n: 300)),
      ];
      final watch = Stopwatch()..start();
      final result = RouteMatch.groups(entries);
      watch.stop();
      expect(result.values.toSet(), {1});
      expect(watch.elapsedMilliseconds, lessThan(2000));
    });

    test('every entry appears in the result', () {
      final entries = [
        for (var id = 1; id <= 6; id++) _ride(id, _line(offsetM: id * 1000.0)),
      ];
      expect(RouteMatch.groups(entries).keys, [1, 2, 3, 4, 5, 6]);
    });
  });
}

/// Points that must never be read.
class _UnreadablePoints extends ListBase<LatLng> {
  @override
  int get length => throw StateError('points were read');
  @override
  set length(int value) => throw StateError('points were read');
  @override
  LatLng operator [](int index) => throw StateError('points were read');
  @override
  void operator []=(int index, LatLng value) =>
      throw StateError('points were read');
}
