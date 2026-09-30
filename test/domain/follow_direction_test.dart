import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/follow_direction.dart';
import 'package:retrail/domain/heading.dart' show LatLng;
import 'package:retrail/domain/route_progress.dart';

/// Metres per degree of latitude for the Haversine radius (6371000 m).
const _mPerDeg = 6371000 * math.pi / 180;

/// A point [northM] metres north and [eastM] metres east of (48°, 11°).
LatLng at(double northM, double eastM) => (
  lat: 48.0 + northM / _mPerDeg,
  lng: 11.0 + eastM / (_mPerDeg * math.cos(48.0 * math.pi / 180)),
);

/// 300 m due north in three 100 m segments.
final _straight = RouteTrack([at(0, 0), at(100, 0), at(200, 0), at(300, 0)]);

void main() {
  group('directionAtJoin', () {
    test('at the start is forward', () {
      expect(directionAtJoin(_straight, at(0, 0)), FollowDirection.forward);
    });

    test('29 m from the start is still forward', () {
      expect(directionAtJoin(_straight, at(-29, 0)), FollowDirection.forward);
    });

    test('at the finish is reverse', () {
      expect(directionAtJoin(_straight, at(300, 0)), FollowDirection.reverse);
    });

    test('mid-route is undecided', () {
      expect(directionAtJoin(_straight, at(150, 0)), FollowDirection.undecided);
    });

    test('31 m from the start is undecided', () {
      expect(directionAtJoin(_straight, at(-31, 0)), FollowDirection.undecided);
    });

    test('a loop is undecided even at the start', () {
      final loop = RouteTrack([
        at(0, 0),
        at(0, 200),
        at(200, 200),
        at(200, 0),
        at(5, 0),
      ]);
      expect(directionAtJoin(loop, at(0, 0)), FollowDirection.undecided);
    });

    test('a single-point route is undecided', () {
      expect(
        directionAtJoin(RouteTrack([at(0, 0)]), at(0, 0)),
        FollowDirection.undecided,
      );
    });
  });

  group('decideDirection', () {
    test('no advance is undecided', () {
      expect(
        decideDirection(forwardAdvanceM: 0, reverseAdvanceM: 0),
        FollowDirection.undecided,
      );
    });

    test('just under the threshold is undecided', () {
      expect(
        decideDirection(forwardAdvanceM: 24.9, reverseAdvanceM: 0),
        FollowDirection.undecided,
      );
    });

    test('forward advance at the threshold is forward', () {
      expect(
        decideDirection(forwardAdvanceM: 25, reverseAdvanceM: 0),
        FollowDirection.forward,
      );
    });

    test('reverse advance at the threshold is reverse', () {
      expect(
        decideDirection(forwardAdvanceM: 0, reverseAdvanceM: 25),
        FollowDirection.reverse,
      );
    });

    test('a tie goes to forward', () {
      expect(
        decideDirection(forwardAdvanceM: 30, reverseAdvanceM: 30),
        FollowDirection.forward,
      );
    });
  });

  group('RiddenRange', () {
    test('.at starts as a single point', () {
      const r = RiddenRange.at(100);
      expect(r.loM, 100);
      expect(r.hiM, 100);
    });

    test('extend grows the range in both directions', () {
      final r = const RiddenRange.at(100).extend(150);
      expect((r.loM, r.hiM), (100, 150));
      final r2 = r.extend(80);
      expect((r2.loM, r2.hiM), (80, 150));
    });

    test('extending with a value inside changes nothing', () {
      final r = const RiddenRange(80, 150).extend(120);
      expect((r.loM, r.hiM), (80, 150));
    });
  });
}
