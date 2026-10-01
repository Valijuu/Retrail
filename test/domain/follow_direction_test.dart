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

/// A "6", 600 m: 300 m south, a 100 m square loop, finishing on the first leg
/// at along 200.
final _six = RouteTrack([
  at(300, 0),
  at(0, 0),
  at(0, 100),
  at(100, 100),
  at(100, 0),
]);

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

    test(
      'at the start of a "6" whose finish lies on its middle is forward',
      () {
        expect(directionAtJoin(_six, at(300, 0)), FollowDirection.forward);
      },
    );

    test(
      'at the finish of a "6" that lies on its middle (along 200 of 600) '
      'is undecided',
      () {
        expect(directionAtJoin(_six, at(100, 0)), FollowDirection.undecided);
      },
    );

    test(
      'at the start of a route that lies on its own middle (along 400 of '
      '600) is undecided',
      () {
        final sixReversed = RouteTrack(_six.points.reversed.toList());
        expect(
          directionAtJoin(sixReversed, at(100, 0)),
          FollowDirection.undecided,
        );
      },
    );

    test('a single-point route is undecided', () {
      expect(
        directionAtJoin(RouteTrack([at(0, 0)]), at(0, 0)),
        FollowDirection.undecided,
      );
    });

    test('an empty route is undecided', () {
      expect(
        directionAtJoin(RouteTrack(const []), at(0, 0)),
        FollowDirection.undecided,
      );
    });
  });

  group('decideDirection', () {
    const d = followDirectionDecisionM;

    test('no displacement is undecided', () {
      expect(decideDirection(const []), FollowDirection.undecided);
    });

    test('just short of the decision distance ahead is undecided', () {
      expect(decideDirection(const [d - 0.1]), FollowDirection.undecided);
    });

    test('the decision distance ahead is forward', () {
      expect(decideDirection(const [d]), FollowDirection.forward);
    });

    test('just short of the decision distance behind is undecided', () {
      expect(decideDirection(const [-d + 0.1]), FollowDirection.undecided);
    });

    test('the decision distance behind is reverse', () {
      expect(decideDirection(const [-d]), FollowDirection.reverse);
    });

    test('ahead on one pass and behind on another (the same road both ways) '
        'is forward', () {
      expect(decideDirection(const [-d, d]), FollowDirection.forward);
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
