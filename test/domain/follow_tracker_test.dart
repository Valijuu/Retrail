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

/// An out-and-back: 200 m north, then back south 3 m east of the way out.
final _outAndBack = [at(0, 0), at(200, 0), at(0, 3)];

/// A lollipop: a 300 m stem north, a 200 m square loop east at its top, then
/// the stem back to the start. L = 1400 m.
final _lollipop = [
  at(0, 0),
  at(300, 0),
  at(500, 0),
  at(500, 200),
  at(300, 200),
  at(300, 0),
  at(0, 0),
];

/// Joins [_lollipop] at north 10 and rides it all the way round back to the
/// join, 10 m per fix.
final _lollipopLap = [
  for (var n = 10.0; n <= 500; n += 10) at(n, 0),
  for (var e = 10.0; e <= 200; e += 10) at(500, e),
  for (var n = 490.0; n >= 300; n -= 10) at(n, 200),
  for (var e = 190.0; e >= 0; e -= 10) at(300, e),
  for (var n = 290.0; n >= 10; n -= 10) at(n, 0),
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

    test('join mid-route + 40 m forward → forward, range 150–190', () {
      final t = _ride(_straight, [at(150, 0), at(170, 0), at(190, 0)]);
      expect(t.direction, FollowDirection.forward);
      expect(t.progress!.alongM, closeTo(190, 0.5));
      expect(t.range!.loM, closeTo(150, 0.5));
      expect(t.range!.hiM, closeTo(190, 0.5));
    });

    test('join mid-route + 40 m back → reverse, along 190', () {
      final t = _ride(_straight, [at(150, 0), at(140, 0), at(120, 0)]);
      expect(t.direction, FollowDirection.undecided);
      final r = t.next(at(110, 0));
      expect(r.direction, FollowDirection.reverse);
      expect(r.progress!.alongM, closeTo(190, 0.5));
      expect(r.range!.loM, closeTo(110, 0.5));
      expect(r.range!.hiM, closeTo(150, 0.5));
    });

    test('GPS jitter 16 m ahead while standing at the join, then 36 m back '
        '→ reverse, range 114–150', () {
      final t = _ride(_straight, [
        at(150, 0),
        at(158, 0),
        at(150, 0),
        at(166, 0),
        at(150, 0),
        at(140, 0),
        at(125, 0),
      ]);
      expect(t.direction, FollowDirection.undecided);
      final r = t.next(at(114, 0));
      expect(r.direction, FollowDirection.reverse);
      expect(r.range!.loM, closeTo(114, 0.5));
      expect(r.range!.hiM, closeTo(150, 0.5));
    });

    test('decided forward: the range grows to the furthest point', () {
      final t = _ride(_straight, [at(150, 0), at(190, 0), at(230, 0)]);
      expect(t.range!.loM, closeTo(150, 0.5));
      expect(t.range!.hiM, closeTo(230, 0.5));
    });

    test('decided forward, a 70 m gap between fixes: progress catches up '
        'within one more fix', () {
      // Catch-up per fix: the pace (the average move over the last fixes, or
      // this move − 25 m for a gap) + 2 m, then 25 % of the rest. The 70 m
      // fix advances 190 → ~243 (pace 45); the next fix's pace, averaged
      // over the gap, covers the remaining ~17 m.
      final t = _ride(_straight, [at(150, 0), at(170, 0), at(190, 0)]);
      expect(t.direction, FollowDirection.forward);
      final gap = t.next(at(260, 0));
      expect(gap.progress!.alongM, inExclusiveRange(190, 260));
      final caught = gap.next(at(260, 0));
      expect(caught.progress!.alongM, closeTo(260, 0.5));
      expect(caught.range!.hiM, closeTo(260, 0.5));
    });

    test('decided reverse: the range grows in original metres', () {
      final t = _ride(_straight, [at(299, 0), at(250, 0), at(200, 0)]);
      expect(t.range!.loM, closeTo(200, 0.5));
      expect(t.range!.hiM, closeTo(299, 0.5));
    });

    test('loop joined at its start and ridden forward (C1) → forward, range '
        'within 0–40', () {
      final t = _ride(_loop(5), [at(0, 1), at(10, 0), at(25, 0), at(40, 0)]);
      expect(t.direction, FollowDirection.forward);
      expect(t.range!.loM, lessThanOrEqualTo(1));
      expect(t.range!.hiM, closeTo(40, 0.5));
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
      expect(t.next(at(40, 0)).direction, FollowDirection.forward);
    });

    test('out-and-back joined at 50 and ridden to 90 → forward, range within '
        '50–90.5', () {
      final t = _ride(
        [at(0, 0), at(200, 0), at(0, 3)],
        [at(50, 0), at(70, 0), at(90, 0)],
      );
      expect(t.direction, FollowDirection.forward);
      expect(t.range!.loM, closeTo(50, 0.5));
      expect(t.range!.hiM, lessThanOrEqualTo(90.5));
    });

    test('joined at a loop\'s finish end, the start nearby is no advance: '
        'ridden 40 m back → reverse', () {
      final t = _ride(_loop(5), [at(0, 5), at(0, 15), at(0, 30), at(0, 45)]);
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
      // The range is in metres of the route laid out twice: either lap.
      final lapM = t.track.lengthM;
      expect(t.range!.loM % lapM, closeTo(315, 0.5));
      expect(t.range!.hiM - t.range!.loM, lessThanOrEqualTo(80.5));
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
      final t = _ride(_loop(5), [at(0, 1), at(15, 0), at(30, 0), at(45, 0)]);
      expect(t.direction, FollowDirection.forward);
      // Far from the progress point: not on its pass any more.
      final j = t.next(at(0, 60));
      expect(j.progress!.alongM, closeTo(340, 0.5));
      // The part ridden before stays; the new pass, a point so far, isn't
      // ridden yet.
      expect(j.riddenIntervals, t.riddenIntervals);
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

    test(
      'loop decided forward to 45, then a jump to 340 and on to 360 (#51): '
      'intervals 0–45 and 340–360, not the skipped part between',
      () {
        final t = _ride(_loop(5), [
          at(0, 1),
          at(15, 0),
          at(30, 0),
          at(45, 0),
          at(0, 60),
          at(0, 50),
          at(0, 40),
        ]);
        expect(t.riddenIntervals, hasLength(2));
        final [(from1, to1), (from2, to2)] = t.riddenIntervals;
        expect(from1, lessThanOrEqualTo(1));
        expect(to1, closeTo(45, 0.5));
        expect(from2, closeTo(340, 0.5));
        expect(to2, closeTo(360, 0.5));
      },
    );

    test(
      'open U route ridden to 100, a shortcut across to 350 and on to 390 '
      '(#51): intervals 0–100 and 350–390',
      () {
        // 200 m north, 50 m east, 200 m back south: L = 450.
        final u = [at(0, 0), at(200, 0), at(200, 50), at(0, 50)];
        final t = _ride(u, [
          for (var n = 0.0; n <= 100; n += 10) at(n, 0),
          for (var n = 100.0; n >= 60; n -= 10) at(n, 50),
        ]);
        expect(t.direction, FollowDirection.forward);
        expect(t.riddenIntervals, hasLength(2));
        final [(from1, to1), (from2, to2)] = t.riddenIntervals;
        expect(from1, closeTo(0, 0.5));
        expect(to1, closeTo(100, 0.5));
        expect(from2, closeTo(350, 0.5));
        expect(to2, closeTo(390, 0.5));
      },
    );

    test(
      'open U route 120 m wide ridden to 100, then across it off route and on '
      'to 660 (#51): intervals 0–100 and 620–660',
      () {
        // 300 m north, 120 m east, 300 m back south: L = 720.
        final u = [at(0, 0), at(300, 0), at(300, 120), at(0, 120)];
        final t = _ride(u, [
          for (var n = 0.0; n <= 100; n += 10) at(n, 0),
          at(100, 40),
          at(100, 80),
          for (var n = 100.0; n >= 60; n -= 10) at(n, 120),
        ]);
        expect(t.riddenIntervals, hasLength(2));
        final [(from1, to1), (from2, to2)] = t.riddenIntervals;
        expect(from1, closeTo(0, 0.5));
        expect(to1, closeTo(100, 0.5));
        expect(from2, closeTo(620, 0.5));
        expect(to2, closeTo(660, 0.5));
      },
    );

    test(
      'off route alongside the route and back on 140 m further (#51): no '
      'shortcut, one interval 0–240',
      () {
        final t = _ride(_straight, [
          for (var n = 0.0; n <= 100; n += 10) at(n, 0),
          for (var n = 120.0; n <= 180; n += 20) at(n, 40),
          at(240, 0),
        ]);
        expect(t.riddenIntervals, hasLength(1));
        final (from, to) = t.riddenIntervals.single;
        expect(from, closeTo(0, 0.5));
        expect(to, closeTo(240, 0.5));
      },
    );

    test(
      'a straight route left at 100 for another road 100 m away and rejoined '
      'at 240 (#51): a new way, intervals 0–100 and 240–260',
      () {
        final t = _ride(_straight, [
          for (var n = 0.0; n <= 100; n += 10) at(n, 0),
          for (var e = 40.0; e <= 100; e += 30) at(100, e),
          for (var n = 140.0; n <= 240; n += 50) at(n, 100),
          at(240, 0),
          at(250, 0),
          at(260, 0),
        ]);
        expect(t.riddenIntervals, hasLength(2));
        final [(from1, to1), (from2, to2)] = t.riddenIntervals;
        expect(from1, closeTo(0, 0.5));
        expect(to1, closeTo(100, 0.5));
        expect(from2, closeTo(240, 0.5));
        expect(to2, closeTo(260, 0.5));
      },
    );

    test(
      'a U-turn flip on a loop after a jump keeps both ridden parts, 0–45 '
      'and 340–360 (#51)',
      () {
        final t = _ride(_loop(5), [
          at(0, 1),
          at(15, 0),
          at(30, 0),
          at(45, 0),
          at(0, 60),
          at(0, 50),
          at(0, 40),
        ]).flip();
        expect(t.direction, FollowDirection.reverse);
        expect(t.riddenIntervals, hasLength(2));
        final [(from1, to1), (from2, to2)] = t.riddenIntervals;
        expect(from1, lessThanOrEqualTo(1));
        expect(to1, closeTo(45, 0.5));
        expect(from2, closeTo(340, 0.5));
        expect(to2, closeTo(360, 0.5));
      },
    );

    test('open route: one ridden interval, 150–190', () {
      final t = _ride(_straight, [at(150, 0), at(170, 0), at(190, 0)]);
      expect(t.riddenIntervals, hasLength(1));
      final (from, to) = t.riddenIntervals.single;
      expect(from, closeTo(150, 0.5));
      expect(to, closeTo(190, 0.5));
    });

    test('square loop joined at 340 and ridden across the seam to north 60: '
        'never finished', () {
      for (final t in _trace(_square, _acrossSeam)) {
        expect(t.progress!.isFinished, isFalse, reason: '${t.progress}');
      }
    });

    test('square loop joined at 340 and ridden across the seam: along strictly '
        'increases after the decision', () {
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

    test('square loop joined at 340 and ridden across the seam: remaining ≈ '
        '400 → ≈ 280', () {
      final trace = _trace(_square, _acrossSeam);
      expect(trace.first.progress!.remainingM, closeTo(400, 0.5));
      expect(trace.last.progress!.remainingM, closeTo(280, 0.5));
    });

    test('square loop joined at 340 and ridden across the seam: ridden '
        'intervals 340–400 and 0–60', () {
      final intervals = _trace(_square, _acrossSeam).last.riddenIntervals;
      expect(intervals, hasLength(2), reason: '$intervals');
      expect(intervals[0].$1, closeTo(340, 0.5));
      expect(intervals[0].$2, closeTo(400, 0.5));
      expect(intervals[1].$1, closeTo(0, 0.5));
      expect(intervals[1].$2, closeTo(60, 0.5));
    });

    test('square loop: a full lap from 340 back to 340 → finished, one '
        'interval 0–400', () {
      final t = _trace(_square, _fullLap).last;
      expect(t.progress!.isFinished, isTrue);
      expect(t.progress!.remainingM, closeTo(0, 0.5));
      expect(t.riddenIntervals, hasLength(1), reason: '${t.riddenIntervals}');
      final (from, to) = t.riddenIntervals.single;
      expect(from, 0);
      expect(to, closeTo(400, 0.5));
    });

    test('square loop joined at north 40 and ridden backwards across the seam '
        '→ reverse, remaining ≈ 400 → 300, intervals 340–400 and 0–40', () {
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

    test('loop joined at its start and ridden forward 40 m (C1) → interval '
        '0–40, not finished', () {
      final trace = _trace(_loop(5), [
        at(0, 1),
        at(10, 0),
        at(20, 0),
        at(30, 0),
        at(40, 0),
      ]);
      final t = trace.last;
      expect(t.direction, FollowDirection.forward);
      expect(t.riddenIntervals, hasLength(1));
      final (from, to) = t.riddenIntervals.single;
      expect(from, lessThanOrEqualTo(1));
      expect(to, closeTo(40, 0.5));
      expect(trace.any((t) => t.progress!.isFinished), isFalse);
    });

    test('loop ridden backwards from its finish end (M3) → reverse, intervals '
        'within 315–395.5, never finished', () {
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

    test('loop joined 2.8 m off its start and ridden backwards → reverse, '
        'intervals within the ridden stretch, never finished', () {
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

    test('flip on a loop mid-lap → direction flips, intervals kept, not '
        'finished', () {
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

    test('flip on a loop in lap 1 keeps the ridden part where it is: one '
        'interval 340–380', () {
      final t = _ride(_square, [
        for (var e = 60.0; e >= 20; e -= 10) at(0, e),
      ]);
      expect(t.direction, FollowDirection.forward);
      final f = t.flip().next(at(0, 30)).next(at(0, 40));
      expect(f.riddenIntervals, hasLength(1), reason: '${f.riddenIntervals}');
      final (from, to) = f.riddenIntervals.single;
      expect(from, closeTo(340, 0.5));
      expect(to, closeTo(380, 0.5));
    });

    test('flip on a loop after deciding reverse in lap 1: one interval 10–50, '
        'remaining ≈ 370', () {
      final t = _ride(_square, [
        for (var n = 50.0; n >= 10; n -= 10) at(n, 0),
      ]);
      expect(t.direction, FollowDirection.reverse);
      final f = t.flip().next(at(20, 0)).next(at(30, 0)).next(at(40, 0));
      expect(f.riddenIntervals, hasLength(1), reason: '${f.riddenIntervals}');
      final (from, to) = f.riddenIntervals.single;
      expect(from, closeTo(10, 0.5));
      expect(to, closeTo(50, 0.5));
      expect(f.progress!.remainingM, closeTo(370, 0.5));
    });

    test('square loop joined 20 m before the start/finish and ridden across '
        'it → the lap runs from the join: remaining ≈ 350 after 50 m', () {
      final t = _ride(_square, [
        for (var e = 20.0; e >= 0; e -= 10) at(0, e),
        for (var n = 10.0; n <= 30; n += 10) at(n, 0),
      ]);
      expect(t.direction, FollowDirection.forward);
      expect(t.progress!.remainingM, closeTo(350, 1));
    });

    test('out-and-back ridden out with the GPS nearer the way back: progress '
        'stays on the way out until the turnaround', () {
      final trace = _trace(_outAndBack, [
        for (var n = 100.0; n <= 190; n += 5) at(n, 2.5),
      ]);
      expect(trace.last.direction, FollowDirection.forward);
      for (final t in trace) {
        expect(t.progress!.alongM, lessThanOrEqualTo(191), reason: '$t');
      }
    });

    test('lollipop joined at its start/finish, ridden up the stem (forward by '
        'default) and flipped at the top: a correction, the lap still runs '
        'from the join (#55)', () {
      final t = _ride(_lollipop, [
        for (var n = 0.0; n <= 300; n += 10) at(n, 0),
      ]);
      expect(t.direction, FollowDirection.forward);
      final f = t.flip();
      expect(f.direction, FollowDirection.reverse);
      expect(f.progress!.remainingM, closeTo(1100, 2));
      final on = f.next(at(300, 10)).next(at(300, 20));
      expect(on.progress!.remainingM, closeTo(1080, 2));
      expect(on.progress!.isFinished, isFalse);
    });

    test('a finished loop lap stays finished: riding 60 m on past the join '
        'keeps finished and remaining 0', () {
      final trace = _trace(_square, [
        ..._fullLap,
        for (var e = 50.0; e >= 0; e -= 10) at(0, e),
      ]);
      for (final t in trace.skip(_fullLap.length - 1)) {
        expect(t.progress!.isFinished, isTrue, reason: '${t.progress}');
        expect(t.progress!.remainingM, 0, reason: '${t.progress}');
      }
    });

    test('decided forward on a loop: a jump to another pass does not finish '
        'the lap', () {
      final t = _ride(_loop(5), [at(0, 1), at(15, 0), at(30, 0), at(45, 0)]);
      // Far from the progress point: not on its pass any more.
      final j = t.next(at(0, 60));
      expect(j.progress!.alongM, closeTo(340, 0.5));
      expect(j.progress!.isFinished, isFalse);
      // The jump is re-based into the join: the lap less the 45 m ridden.
      expect(j.progress!.remainingM, closeTo(350, 0.5));
    });

    for (final joinM in <double>[2, 5, 8, 12, 20]) {
      test('out-and-back joined ${joinM.round()} m past its start and ridden forward to '
          '60 → never reverse, forward', () {
        final trace = _trace(_outAndBack, [
          at(joinM, 0),
          for (final n in <double>[20, 30, 40, 50, 60])
            if (n > joinM) at(n, 0),
        ]);
        for (final t in trace) {
          expect(t.direction, isNot(FollowDirection.reverse));
        }
        expect(trace.last.direction, FollowDirection.forward);
      });
    }

    test('lollipop joined at north 10 and ridden round → forward, remaining '
        'at most one lap, finished back at the join', () {
      final trace = _trace(_lollipop, _lollipopLap);
      final lengthM = trace.first.track.lengthM;
      for (final t in trace) {
        expect(t.direction, isNot(FollowDirection.reverse));
        expect(t.progress!.remainingM, lessThanOrEqualTo(lengthM));
      }
      expect(trace.last.progress!.isFinished, isTrue);
    });

    test('decided forward on a loop, then off route and back on it behind '
        'the join → remaining at most one lap', () {
      final trace = _trace(_square, [
        for (var e = 70.0; e >= 30; e -= 10) at(0, e),
        at(-40, 30),
        at(-40, 80),
        at(0, 80),
      ]);
      expect(trace[4].direction, FollowDirection.forward);
      expect(trace.last.progress!.isOffRoute, isFalse);
      for (final t in trace) {
        expect(t.progress!.remainingM, inInclusiveRange(0, 400));
      }
    });
  });
}
