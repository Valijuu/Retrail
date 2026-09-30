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

/// A closed 100 m square loop, L = 400 m.
final _square = _loop(0);

/// Starts following [route] and feeds it [fixes] in order.
FollowTracker _ride(List<LatLng> route, List<LatLng> fixes) =>
    fixes.fold(FollowTracker.start(RouteTrack(route)), (t, p) => t.next(p));

/// Every tracker state while following [route] through [fixes].
List<FollowTracker> _trace(List<LatLng> route, List<LatLng> fixes) {
  var t = FollowTracker.start(RouteTrack(route));
  return [for (final p in fixes) t = t.next(p)];
}

/// Joins [_square] at 340 (east 60 on its last leg), rides west through the
/// start/finish point, then north to (60, 0), 10 m per fix.
final _acrossSeam = [
  for (var e = 60.0; e >= 0; e -= 10) at(0, e),
  for (var n = 10.0; n <= 60; n += 10) at(n, 0),
];

/// Joins [_square] at 340 and rides one full lap back to the join, 10 m per
/// fix.
final _fullLap = [
  for (var e = 60.0; e >= 0; e -= 10) at(0, e),
  for (var n = 10.0; n <= 100; n += 10) at(n, 0),
  for (var e = 10.0; e <= 100; e += 10) at(100, e),
  for (var n = 90.0; n >= 0; n -= 10) at(n, 100),
  for (var e = 90.0; e >= 60; e -= 10) at(0, e),
];

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

    test('a jump to another pass adds no advance: forward jumps along the '
        'loop, reverse rides 30 m → reverse', () {
      final t = _ride(_loop(5), [at(0, 5), at(0, 15), at(0, 25), at(0, 35)]);
      expect(t.direction, FollowDirection.reverse);
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

    test('loop joined 2.8 m off its start and ridden backwards → reverse, '
        'range only the ridden last leg', () {
      final t = _ride(_loop(5), [
        at(2, 2),
        for (var e = 5.0; e <= 70; e += 5) at(0, e),
      ]);
      expect(t.direction, FollowDirection.reverse);
      expect(t.range!.hiM - t.range!.loM, lessThanOrEqualTo(75));
      expect(t.range!.loM, greaterThan(300));
    });

    test('out-and-back joined at 190 and ridden south on the return leg → '
        'forward, no ghost range on the way out', () {
      final t = _ride([at(0, 0), at(200, 0), at(0, 3)], [
        at(190, 0),
        for (var n = 180.0; n >= 140; n -= 10) at(n, 3 * (200 - n) / 200),
      ]);
      expect(t.direction, FollowDirection.forward);
      expect(t.range!.loM, greaterThanOrEqualTo(189));
    });

    test('decided forward: a jump to another pass extends nothing', () {
      final t = _ride(_loop(5), [at(0, 1), at(10, 0), at(20, 0), at(30, 0)]);
      expect(t.direction, FollowDirection.forward);
      final j = t.next(at(0, 20));
      expect(j.progress!.alongM, closeTo(380, 0.5));
      expect(j.range!.loM, t.range!.loM);
      expect(j.range!.hiM, t.range!.hiM);
    });

    test('flip while undecided keeps what the reverse tracker rode', () {
      final t = _ride(_straight, [at(150, 0), at(140, 0)]).flip();
      expect(t.direction, FollowDirection.reverse);
      expect(t.range!.loM, closeTo(140, 0.5));
      expect(t.range!.hiM, closeTo(150, 0.5));
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

  group('FollowTracker on loops', () {
    test('isLoop: a closed square loop is a loop', () {
      expect(FollowTracker.start(RouteTrack(_square)).isLoop, isTrue);
    });
    test('isLoop: an open route is not a loop', () {
      expect(FollowTracker.start(RouteTrack(_straight)).isLoop, isFalse);
    });
    test('isLoop: a loop ending 20 m from its start is a loop', () {
      expect(FollowTracker.start(RouteTrack(_loop(20))).isLoop, isTrue);
    });
    test('open route: no ridden intervals before the decision', () {
      final t = _ride(_straight, [at(150, 0), at(160, 0)]);
      expect(t.riddenIntervals, isEmpty);
    });
    test('open route: one ridden interval, 150–180', () {
      final t = _ride(_straight, [at(150, 0), at(165, 0), at(180, 0)]);
      expect(t.riddenIntervals, hasLength(1));
      final (from, to) = t.riddenIntervals.single;
      expect(from, closeTo(150, 0.5));
      expect(to, closeTo(180, 0.5));
    });
    test('square loop joined at 340 and ridden across the seam to north 60: never finished', () {
      for (final t in _trace(_square, _acrossSeam)) {
        expect(t.progress!.isFinished, isFalse, reason: '${t.progress}');
      }
    });
    test('square loop joined at 340 and ridden across the seam: along strictly increases after the decision', () {
      final decided = _trace(_square, _acrossSeam)
          .where((t) => t.direction == FollowDirection.forward)
          .toList();
      expect(decided, hasLength(greaterThan(5)));
      for (var i = 1; i < decided.length; i++) {
        expect(
          decided[i].progress!.alongM,
          greaterThan(decided[i - 1].progress!.alongM + 9),
          reason: 'fix $i',
        );
      }
    });
    test('square loop joined at 340 and ridden across the seam: remaining ≈ 400 → ≈ 280', () {
      final trace = _trace(_square, _acrossSeam);
      expect(trace.first.progress!.remainingM, closeTo(400, 0.5));
      expect(trace.last.progress!.remainingM, closeTo(280, 0.5));
    });
    test('square loop joined at 340 and ridden across the seam: ridden intervals 340–400 and 0–60', () {
      final intervals = _trace(_square, _acrossSeam).last.riddenIntervals;
      expect(intervals, hasLength(2), reason: '$intervals');
      expect(intervals[0].$1, closeTo(340, 0.5));
      expect(intervals[0].$2, closeTo(400, 0.5));
      expect(intervals[1].$1, closeTo(0, 0.5));
      expect(intervals[1].$2, closeTo(60, 0.5));
    });
    test('square loop: a full lap from 340 back to 340 → finished, one interval 0–400', () {
      final t = _trace(_square, _fullLap).last;
      expect(t.progress!.isFinished, isTrue);
      expect(t.progress!.remainingM, closeTo(0, 0.5));
      expect(t.riddenIntervals, hasLength(1), reason: '${t.riddenIntervals}');
      final (from, to) = t.riddenIntervals.single;
      expect(from, 0);
      expect(to, closeTo(400, 0.5));
    });
    test('square loop joined at north 40 and ridden backwards across the seam → reverse, remaining ≈ 400 → 300, intervals 340–400 and 0–40', () {
      final trace = _trace(_square, [
        for (var n = 40.0; n >= 0; n -= 10) at(n, 0),
        for (var e = 10.0; e <= 60; e += 10) at(0, e),
      ]);
      final decided = trace
          .where((t) => t.direction == FollowDirection.reverse)
          .toList();
      expect(decided.last, same(trace.last));
      for (var i = 1; i < decided.length; i++) {
        expect(
          decided[i].progress!.alongM,
          greaterThan(decided[i - 1].progress!.alongM + 9),
          reason: 'fix $i',
        );
      }
      expect(trace.first.progress!.remainingM, closeTo(400, 0.5));
      expect(trace.last.progress!.remainingM, closeTo(300, 0.5));
      final intervals = trace.last.riddenIntervals;
      expect(intervals, hasLength(2), reason: '$intervals');
      expect(intervals[0].$1, closeTo(340, 0.5));
      expect(intervals[0].$2, closeTo(400, 0.5));
      expect(intervals[1].$1, closeTo(0, 0.5));
      expect(intervals[1].$2, closeTo(40, 0.5));
      expect(trace.any((t) => t.progress!.isFinished), isFalse);
    });
    test('loop joined at its start and ridden forward 30 m (C1) → interval 0–30, not finished', () {
      final trace = _trace(_loop(5), [at(0, 1), at(10, 0), at(20, 0), at(30, 0)]);
      final t = trace.last;
      expect(t.direction, FollowDirection.forward);
      expect(t.riddenIntervals, hasLength(1));
      final (from, to) = t.riddenIntervals.single;
      expect(from, lessThanOrEqualTo(1));
      expect(to, closeTo(30, 0.5));
      expect(trace.any((t) => t.progress!.isFinished), isFalse);
    });
    test('loop ridden backwards from its finish end (M3) → reverse, intervals within 315–395.5, never finished', () {
      final trace = _trace(_loop(5), [
        for (var e = 5.0; e <= 85; e += 10) at(0, e),
      ]);
      expect(trace.last.direction, FollowDirection.reverse);
      final intervals = trace.last.riddenIntervals;
      expect(intervals, hasLength(1), reason: '$intervals');
      expect(intervals.single.$1, closeTo(315, 0.5));
      expect(intervals.single.$2, lessThanOrEqualTo(395.5));
      expect(trace.any((t) => t.progress!.isFinished), isFalse);
    });
    test('loop joined 2.8 m off its start and ridden backwards → reverse, intervals within the ridden stretch, never finished', () {
      final trace = _trace(_loop(5), [
        at(2, 2),
        for (var e = 5.0; e <= 70; e += 5) at(0, e),
      ]);
      expect(trace.last.direction, FollowDirection.reverse);
      final intervals = trace.last.riddenIntervals;
      for (final (from, to) in intervals) {
        expect(from > 300 || to <= 5, isTrue, reason: '$intervals');
      }
      final ridden = intervals.fold(0.0, (m, i) => m + i.$2 - i.$1);
      expect(ridden, lessThanOrEqualTo(75), reason: '$intervals');
      expect(trace.any((t) => t.progress!.isFinished), isFalse);
    });
    test('flip on a loop mid-lap → direction flips, intervals kept, not finished', () {
      final t = _trace(_square, _acrossSeam).last;
      final f = t.flip();
      expect(f.direction, FollowDirection.reverse);
      expect(f.riddenIntervals, t.riddenIntervals);
      expect(f.progress!.isFinished, isFalse);
      // A flip starts a fresh lap from where the rider turned.
      expect(f.progress!.remainingM, closeTo(400, 0.5));
      final back = f.next(at(50, 0));
      expect(back.progress!.alongM, closeTo(f.progress!.alongM + 10, 0.5));
      expect(back.progress!.isFinished, isFalse);
    });
    test('decided forward on a loop: a jump to another pass does not finish the lap', () {
      final t = _ride(_loop(5), [at(0, 1), at(10, 0), at(20, 0), at(30, 0)]);
      final j = t.next(at(0, 20));
      expect(j.progress!.alongM, closeTo(380, 0.5));
      expect(j.progress!.isFinished, isFalse);
      // The jump is re-based into the join: the lap less the 30 m ridden.
      expect(j.progress!.remainingM, closeTo(365, 0.5));
    });
  });
}
