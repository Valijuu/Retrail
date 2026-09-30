import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/follow_direction.dart';
import 'package:retrail/domain/follow_tracker.dart';
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
final _straight = [at(0, 0), at(100, 0), at(200, 0), at(300, 0)];

/// A 100 m square loop ending [endEastM] east of its start.
List<LatLng> _loop(double endEastM) =>
    [at(0, 0), at(100, 0), at(100, 100), at(0, 100), at(0, endEastM)];

/// Starts following [route] and feeds it [fixes] in order.
FollowTracker _ride(List<LatLng> route, List<LatLng> fixes) =>
    fixes.fold(FollowTracker.start(RouteTrack(route)), (t, p) => t.next(p));

void main() {
  group('FollowTracker', () {
    test('join at the start of an open route → forward', () {
      final t = _ride(_straight, [at(1, 0)]);
      expect(t.direction, FollowDirection.forward);
      expect(t.hasJoined, isTrue);
      expect(identical(t.orientedTrack, t.track), isTrue);
    });

    test('join at the finish of an open route → reverse, along 1, remaining '
        '299', () {
      final t = _ride(_straight, [at(299, 0)]);
      expect(t.direction, FollowDirection.reverse);
      expect(t.progress!.alongM, closeTo(1, 0.5));
      expect(t.progress!.remainingM, closeTo(299, 0.5));
      expect(t.orientedTrack.points.first, _straight.last);
    });

    test('before the join nothing is decided and the route is unchanged', () {
      final t = _ride(_straight, [at(150, 100)]);
      expect(t.direction, FollowDirection.undecided);
      expect(t.hasJoined, isFalse);
      expect(t.range, isNull);
      expect(identical(t.orientedTrack, t.track), isTrue);
    });

    test('join mid-route, 15 m forward → still undecided, forward progress',
        () {
      final t = _ride(_straight, [at(150, 0), at(165, 0)]);
      expect(t.direction, FollowDirection.undecided);
      expect(t.progress!.alongM, closeTo(165, 0.5));
      expect(identical(t.orientedTrack, t.track), isTrue);
    });

    test('join mid-route + 25 m forward → forward, range 150–180', () {
      final t = _ride(_straight, [at(150, 0), at(165, 0), at(180, 0)]);
      expect(t.direction, FollowDirection.forward);
      expect(t.progress!.alongM, closeTo(180, 0.5));
      expect(t.range!.loM, closeTo(150, 0.5));
      expect(t.range!.hiM, closeTo(180, 0.5));
    });

    test('join mid-route + 25 m back → reverse, along 180', () {
      final t = _ride(_straight, [at(150, 0), at(140, 0), at(130, 0)]);
      expect(t.direction, FollowDirection.undecided);
      final r = t.next(at(120, 0));
      expect(r.direction, FollowDirection.reverse);
      expect(r.progress!.alongM, closeTo(180, 0.5));
      expect(r.range!.loM, closeTo(120, 0.5));
      expect(r.range!.hiM, closeTo(150, 0.5));
    });

    test('decided forward: the range grows to the furthest point', () {
      final t = _ride(_straight, [at(150, 0), at(180, 0), at(250, 0)]);
      expect(t.range!.loM, closeTo(150, 0.5));
      expect(t.range!.hiM, closeTo(250, 0.5));
    });

    test('decided reverse: the range grows in original metres', () {
      final t = _ride(_straight, [at(299, 0), at(250, 0), at(200, 0)]);
      expect(t.range!.loM, closeTo(200, 0.5));
      expect(t.range!.hiM, closeTo(299, 0.5));
    });

    test('loop joined at its start and ridden forward (C1) → forward, range '
        'within 0–30', () {
      final t = _ride(_loop(5), [at(0, 1), at(10, 0), at(20, 0), at(30, 0)]);
      expect(t.direction, FollowDirection.forward);
      expect(t.range!.loM, lessThanOrEqualTo(1));
      expect(t.range!.hiM, closeTo(30, 0.5));
    });

    test('loop joined at its start: the join alone decides nothing', () {
      final t = _ride(_loop(5), [at(0, 1)]);
      expect(t.direction, FollowDirection.undecided);
    });

    test('loop finishing 20 m east (C2) ridden 23 m forward → never reverse, '
        'not finished', () {
      var t = FollowTracker.start(RouteTrack(_loop(20)));
      for (final p in [at(0, 1), at(8, 0), at(16, 0), at(23, 0)]) {
        t = t.next(p);
        expect(t.direction, isNot(FollowDirection.reverse));
        expect(t.progress!.isFinished, isFalse);
      }
      expect(t.next(at(30, 0)).direction, FollowDirection.forward);
    });

    test('out-and-back joined at 50 and ridden to 80 → forward, range within '
        '50–80.5', () {
      final t = _ride(
        [at(0, 0), at(200, 0), at(0, 3)],
        [at(50, 0), at(60, 0), at(80, 0)],
      );
      expect(t.direction, FollowDirection.forward);
      expect(t.range!.loM, closeTo(50, 0.5));
      expect(t.range!.hiM, lessThanOrEqualTo(80.5));
    });

    test('a jump to another pass adds no advance', () {
      final t = _ride(_loop(5), [at(0, 5), at(0, 15), at(0, 25), at(0, 35)]);
      expect(t.direction, FollowDirection.undecided);
    });

    test('loop joined at its finish end and ridden backwards (M3) → reverse',
        () {
      final t = _ride(_loop(5), [
        for (var e = 5.0; e <= 85; e += 10) at(0, e),
      ]);
      expect(t.direction, FollowDirection.reverse);
    });

    test('loop ridden backwards from its finish end (M3): the range stays on '
        'the last leg', () {
      final t = _ride(_loop(5), [
        for (var e = 5.0; e <= 85; e += 10) at(0, e),
      ]);
      expect(t.range!.loM, closeTo(315, 0.5));
      expect(t.range!.hiM, lessThanOrEqualTo(395.5));
    });

    test('flip before the join is a no-op', () {
      final t = _ride(_straight, [at(150, 100)]);
      expect(identical(t.flip(), t), isTrue);
    });

    test('flip after forward at 200 → reverse, along 100, range kept', () {
      final t = _ride(_straight, [at(150, 0), at(180, 0), at(200, 0)]);
      final f = t.flip();
      expect(f.direction, FollowDirection.reverse);
      expect(f.progress!.alongM, closeTo(100, 0.5));
      expect(f.range!.loM, t.range!.loM);
      expect(f.range!.hiM, t.range!.hiM);
      expect(f.next(at(190, 0)).progress!.alongM, closeTo(110, 0.5));
    });

    test('flip while undecided at 120 → reverse, along 180', () {
      final t = _ride(_straight, [at(120, 0)]).flip();
      expect(t.direction, FollowDirection.reverse);
      expect(t.progress!.alongM, closeTo(180, 0.5));
    });

    test('flip back from reverse → forward', () {
      final t = _ride(_straight, [at(299, 0), at(250, 0)]).flip();
      expect(t.direction, FollowDirection.forward);
      expect(t.progress!.alongM, closeTo(250, 0.5));
      expect(identical(t.orientedTrack, t.track), isTrue);
    });

    test('flip while off route keeps the mirrored along, joined', () {
      final t = _ride(
        _straight,
        [at(150, 0), at(180, 0), at(200, 0), at(200, 80)],
      ).flip();
      expect(t.progress!.isOffRoute, isTrue);
      expect(t.progress!.hasJoined, isTrue);
      expect(t.progress!.alongM, closeTo(100, 0.5));
    });
  });
}
