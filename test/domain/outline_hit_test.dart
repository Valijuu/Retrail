import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/outline_hit.dart';
import 'package:retrail/domain/ride_outline.dart';

const _calc = HaversineDistanceCalculator();

/// Metres per degree on the Haversine sphere (radius 6371 km).
const _metresPerDegree = 6371000 * math.pi / 180;

/// A point [north] / [east] metres from the origin (0, 0).
LatLng _at(double north, double east) =>
    (lat: north / _metresPerDegree, lng: east / _metresPerDegree);

/// Metres per pixel at zoom 14 on the equator: 24 px are about 114.6 m.
final _zoom14M = metresPerPixel(zoom: 14, latitude: 0);

OutlineCandidate _ride(
  int id,
  List<LatLng> points, {
  int timestampMs = 0,
  void Function()? onDecode,
}) {
  final outline = RideOutline(points);
  return OutlineCandidate(
    rideId: id,
    timestampMs: timestampMs,
    bounds: outline.bounds,
    outline: () {
      onDecode?.call();
      return outline;
    },
  );
}

List<OutlineHit> _find(
  LatLng tap,
  List<OutlineCandidate> rides, {
  double zoom = 14,
  Set<int> best = const {},
}) => OutlineHit.find(
  tap: tap,
  zoom: zoom,
  candidates: rides,
  bestRideIds: best,
  distance: _calc,
);

void main() {
  group('metresPerPixel', () {
    test('zoom 14, latitude 0: 24 px are about 114.6 m', () {
      expect(_zoom14M * 24, closeTo(114.6, 0.1));
    });

    test('zoom 16, latitude 60: 24 px are about 14.3 m', () {
      expect(metresPerPixel(zoom: 16, latitude: 60) * 24, closeTo(14.3, 0.1));
    });
  });

  group('OutlineHit.find', () {
    final line = [_at(0, -500), _at(0, 500)];

    test('no rides: no hits', () {
      expect(_find(_at(0, 0), const []), isEmpty);
    });

    test('an outline with fewer than two points never hits', () {
      expect(
        _find(_at(0, 0), [
          _ride(1, const []),
          _ride(2, [_at(0, 0)]),
        ]),
        isEmpty,
      );
    });

    test(
      'a ride whose line passes under the tap is a hit with its distance',
      () {
        final hits = _find(_at(10, 0), [_ride(1, line)]);
        expect(hits.single.rideId, 1);
        expect(hits.single.distanceM, closeTo(10, 0.01));
      },
    );

    test('tap beside a line: 40 px away at zoom 14 is no hit', () {
      expect(_find(_at(40 * _zoom14M, 0), [_ride(1, line)]), isEmpty);
    });

    test('a line 20 px away at zoom 14 is a hit (tolerance 24 px)', () {
      expect(_find(_at(20 * _zoom14M, 0), [_ride(1, line)]), hasLength(1));
    });

    test('tap on a shared stretch: both rides hit, the closer one first', () {
      final near = [_at(5, -500), _at(5, 500)];
      final far = [_at(-30, -500), _at(-30, 500)];
      final hits = _find(_at(0, 0), [_ride(1, far), _ride(2, near)]);
      expect(hits.map((h) => h.rideId), [2, 1]);
    });

    test('equal distance: the newest ride comes first', () {
      final hits = _find(_at(0, 0), [
        _ride(1, line, timestampMs: 100),
        _ride(2, line, timestampMs: 300),
        _ride(3, line, timestampMs: 200),
      ]);
      expect(hits.map((h) => h.rideId), [2, 3, 1]);
    });

    test(
      'every ride appears once even with several segments under the tap',
      () {
        final zigzag = [
          _at(0, -100),
          _at(0, 0),
          _at(5, 0),
          _at(0, 0),
          _at(0, 100),
        ];
        final hits = _find(_at(0, 0), [_ride(1, zigzag)]);
        expect(hits, hasLength(1));
        expect(hits.single.distanceM, closeTo(0, 0.01));
      },
    );

    test('a hit is marked best when its ride is among the best ride ids', () {
      final hits = _find(
        _at(0, 0),
        [_ride(1, line, timestampMs: 1), _ride(2, line, timestampMs: 2)],
        best: {1},
      );
      expect(hits.firstWhere((h) => h.rideId == 1).isBest, isTrue);
      expect(hits.firstWhere((h) => h.rideId == 2).isBest, isFalse);
    });

    test('an outline whose bounds are far from the tap is never decoded', () {
      var decoded = 0;
      final faraway = _ride(1, [
        _at(50000, 0),
        _at(50000, 500),
      ], onDecode: () => decoded++);
      expect(_find(_at(0, 0), [faraway]), isEmpty);
      expect(decoded, 0);
    });
  });
}
