import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';
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

/// Feeds [fixes] through [track.locate] in order, returning the last progress.
RouteProgress? walk(RouteTrack track, List<LatLng> fixes) {
  RouteProgress? p;
  for (final f in fixes) {
    p = track.locate(f, previous: p);
  }
  return p;
}

/// One metre per leg, whatever the coordinates.
class _OneMetreLegs implements DistanceCalculator {
  const _OneMetreLegs();

  @override
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) =>
      1;
}

void main() {
  group('RouteTrack.locate', () {
    test('an empty or single-point reference yields no progress', () {
      expect(RouteTrack(const []).locate(at(0, 0)), isNull);
      expect(RouteTrack([at(0, 0)]).locate(at(0, 0)), isNull);
      expect(RouteTrack([at(5, 5), at(5, 5)]).locate(at(0, 0)), isNull);
    });

    test('first fix on a straight route: along, remaining, on route', () {
      final p = RouteTrack(_straight).locate(at(150, 0))!;
      expect(p.alongM, closeTo(150, 0.5));
      expect(p.remainingM, closeTo(150, 0.5));
      expect(p.offsetM, closeTo(0, 0.5));
      expect(p.isOffRoute, isFalse);
      expect(p.hasJoined, isTrue);
      expect(p.isFinished, isFalse);
    });

    test('beside the route: offset is the distance to the line', () {
      final p = RouteTrack(_straight).locate(at(150, 20))!;
      expect(p.offsetM, closeTo(20, 0.5));
      expect(p.isOffRoute, isFalse);
    });

    test('exactly at the threshold still counts as on route', () {
      expect(RouteTrack(_straight).locate(at(150, 30))!.isOffRoute, isFalse);
    });

    test('first fix beyond the threshold: off route, not joined, along 0', () {
      final p = RouteTrack(_straight).locate(at(150, 31))!;
      expect(p.isOffRoute, isTrue);
      expect(p.hasJoined, isFalse);
      expect(p.alongM, 0);
      expect(p.remainingM, closeTo(300, 0.5));
      expect(p.offsetM, closeTo(31, 0.5));
    });

    test('joining mid-segment near a vertex picks the true projection', () {
      // Segment 2's start vertex (100 m) is also within 30 m — must not win.
      final p = RouteTrack(_straight).locate(at(90, 10))!;
      expect(p.alongM, closeTo(90, 0.5));
    });

    test('loop: at the start, the nearby finish does not count', () {
      // Square loop whose finish lies 5 m east of the start.
      final loop = RouteTrack([
        at(0, 0),
        at(100, 0),
        at(100, 100),
        at(0, 100),
        at(0, 5),
      ]);
      final p = loop.locate(at(0, 1))!;
      expect(p.alongM, lessThan(10));
      expect(p.isFinished, isFalse);
    });

    test('out-and-back on the same road: progress follows the return leg', () {
      final track = RouteTrack([at(0, 0), at(200, 0), at(0, 3)]);
      final p = walk(track, [
        at(50, 0),
        at(100, 0),
        at(150, 0),
        at(195, 0),
        at(199, 2),
        at(180, 3),
        at(150, 3),
      ])!;
      expect(p.alongM, closeTo(250, 3));
    });

    test('a crossing far ahead does not capture the position', () {
      // The last leg crosses the first one at (500, 0), 2100 m along.
      final track = RouteTrack([
        at(0, 0),
        at(1000, 0),
        at(1000, 300),
        at(500, 300),
        at(500, -300),
      ]);
      final p = walk(track, [at(400, 0), at(450, 0), at(500, 0), at(550, 0)])!;
      expect(p.alongM, closeTo(550, 1));
    });

    test('first fix exactly on a crossing takes the earlier pass', () {
      final track = RouteTrack([
        at(0, 0),
        at(1000, 0),
        at(1000, 300),
        at(500, 300),
        at(500, -300),
      ]);
      expect(track.locate(at(500, 0))!.alongM, closeTo(500, 1));
    });

    test('off route after joining keeps the last progress', () {
      final track = RouteTrack(_straight);
      final p = walk(track, [at(100, 0), at(150, 80)])!;
      expect(p.isOffRoute, isTrue);
      expect(p.hasJoined, isTrue);
      expect(p.alongM, closeTo(100, 0.5));
      expect(p.offsetM, closeTo(80, 1));
    });

    test('rejoining after off route continues forward', () {
      final track = RouteTrack(_straight);
      final p = walk(track, [at(100, 0), at(150, 80), at(250, 5)])!;
      expect(p.isOffRoute, isFalse);
      expect(p.alongM, closeTo(250, 0.5));
    });

    test('GPS jitter behind the last progress holds it (never decreases)', () {
      final track = RouteTrack(_straight);
      final p = walk(track, [at(150, 0), at(147, 1), at(149, -1)])!;
      expect(p.alongM, closeTo(150, 0.5));
      expect(p.isOffRoute, isFalse);
    });

    test('a shortcut beyond the look-ahead window rejoins further on', () {
      final track = RouteTrack([at(0, 0), at(1000, 0)]);
      final p = walk(track, [at(100, 0), at(800, 0)])!;
      expect(p.alongM, closeTo(800, 1));
      expect(p.isOffRoute, isFalse);
    });

    test('finish reached near the end', () {
      final track = RouteTrack(_straight);
      final p = walk(track, [at(290, 0), at(298, 0)])!;
      expect(p.isFinished, isTrue);
      expect(p.remainingM, closeTo(2, 0.5));
    });

    test(
      "out-and-back: GPS error towards the return leg doesn't jump legs",
      () {
        final track = RouteTrack([at(0, 0), at(200, 0), at(0, 3)]);
        RouteProgress? p;
        var last = 0.0;
        for (final n in [20.0, 40.0, 50.0, 60.0, 80.0]) {
          p = track.locate(at(n, n == 50 ? 2.5 : 0), previous: p);
          expect(p!.alongM, closeTo(n, 3));
          expect(p.alongM, greaterThanOrEqualTo(last));
          last = p.alongM;
        }
      },
    );

    test('rejoining out-and-back picks the pass nearest the last progress', () {
      final track = RouteTrack([at(0, 0), at(200, 0), at(0, 3)]);
      final p = walk(track, [
        at(50, 0),
        at(100, 0),
        at(150, 0),
        at(150, 60),
        at(100, 1),
      ])!;
      expect(p.isOffRoute, isFalse);
      expect(p.alongM, closeTo(100, 3));
    });

    test('rejoining on a loop near the start does not jump to the finish', () {
      final loop = RouteTrack([
        at(0, 0),
        at(100, 0),
        at(100, 100),
        at(0, 100),
        at(0, 5),
      ]);
      final p = walk(loop, [
        at(0, 0),
        at(50, 0),
        at(100, 0),
        at(50, 50),
        at(5, 2),
      ])!;
      expect(p.isOffRoute, isFalse);
      expect(p.alongM, lessThan(10));
      expect(p.isFinished, isFalse);
    });
  });

  group('RouteTrack.reversed', () {
    test('walks the points backwards with the same length', () {
      final r = RouteTrack(_straight).reversed();
      expect(r.points, _straight.reversed.toList());
      expect(r.lengthM, closeTo(300, 0.5));
      expect(r.cumulativeM[0], 0);
      expect(r.cumulativeM[1], closeTo(100, 0.5));
      expect(r.cumulativeM[2], closeTo(200, 0.5));
      expect(r.cumulativeM[3], closeTo(300, 0.5));
    });

    test('keeps the injected distance calculator', () {
      final r = RouteTrack(
        _straight,
        distance: const _OneMetreLegs(),
      ).reversed();
      expect(r.lengthM, 3);
    });

    test('a single-point route stays a single point of length 0', () {
      final r = RouteTrack([at(0, 0)]).reversed();
      expect(r.points.length, 1);
      expect(r.lengthM, 0);
    });
  });

  group('RouteTrack.segmentBetween', () {
    void expectPoints(List<LatLng> actual, List<LatLng> expected) {
      expect(actual.length, expected.length);
      for (var i = 0; i < expected.length; i++) {
        expect(actual[i].lat, closeTo(expected[i].lat, 1e-9));
        expect(actual[i].lng, closeTo(expected[i].lng, 1e-9));
      }
    }

    test('the whole route yields every point', () {
      expectPoints(RouteTrack(_straight).segmentBetween(0, 300), _straight);
    });

    test('interior cuts are interpolated', () {
      expectPoints(RouteTrack(_straight).segmentBetween(150, 250), [
        at(150, 0),
        at(200, 0),
        at(250, 0),
      ]);
    });

    test('from after to is swapped', () {
      expectPoints(RouteTrack(_straight).segmentBetween(250, 150), [
        at(150, 0),
        at(200, 0),
        at(250, 0),
      ]);
    });

    test('cuts on vertices add no duplicate points', () {
      expectPoints(RouteTrack(_straight).segmentBetween(100, 200), [
        at(100, 0),
        at(200, 0),
      ]);
    });

    test('an empty range yields nothing', () {
      expect(RouteTrack(_straight).segmentBetween(120, 120), isEmpty);
    });

    test('values are clamped to the route', () {
      expectPoints(RouteTrack(_straight).segmentBetween(-50, 50), [
        at(0, 0),
        at(50, 0),
      ]);
    });

    test('both cuts inside one leg', () {
      expectPoints(RouteTrack(_straight).segmentBetween(120, 180), [
        at(120, 0),
        at(180, 0),
      ]);
    });

    test('a cut on the last vertex ends there', () {
      expectPoints(RouteTrack(_straight).segmentBetween(250, 300), [
        at(250, 0),
        at(300, 0),
      ]);
    });

    test('a swapped whole-route range yields every point', () {
      expectPoints(RouteTrack(_straight).segmentBetween(300, 0), _straight);
    });

    test('a route without length yields nothing', () {
      expect(RouteTrack([at(5, 5), at(5, 5)]).segmentBetween(0, 10), isEmpty);
      expect(RouteTrack([at(0, 0)]).segmentBetween(0, 10), isEmpty);
    });
  });

  group('RouteTrack.hitsWithin', () {
    final outAndBack = RouteTrack([at(0, 0), at(200, 0), at(0, 3)]);

    test('a point on the route: one hit at its along, offset 0', () {
      final hits = RouteTrack(_straight).hitsWithin(at(150, 0), 100, 200);
      expect(hits, hasLength(1));
      expect(hits.single.alongM, closeTo(150, 0.5));
      expect(hits.single.offsetM, closeTo(0, 0.5));
    });

    test('a point off the route: no hits', () {
      expect(RouteTrack(_straight).hitsWithin(at(150, 31), 0, 300), isEmpty);
    });

    test('a hit is clamped to the window', () {
      final hits = RouteTrack(_straight).hitsWithin(at(150, 0), 100, 140);
      expect(hits.single.alongM, closeTo(140, 0.5));
      expect(hits.single.offsetM, closeTo(10, 0.5));
    });

    test('by both legs of an out-and-back: one hit per leg', () {
      final hits = outAndBack.hitsWithin(at(150, 1), 0, 400);
      expect(hits.map((h) => h.alongM.round()), [150, 250]);
    });
  });

  group('RouteTrack.passesOf', () {
    test('by the start of an out-and-back: the way out and the way back', () {
      final track = RouteTrack([at(0, 0), at(200, 0), at(0, 3)]);
      final passes = track.passesOf(at(10, 1));
      expect(passes.map((h) => h.alongM.round()), [10, 390]);
    });

    test('off the route: none', () {
      expect(RouteTrack(_straight).passesOf(at(150, 31)), isEmpty);
    });
  });

  group('RouteTrack.progressAt', () {
    test('progress on route at a hit', () {
      final track = RouteTrack(_straight);
      final p = track.progressAt(at(299, 1), (alongM: 299, offsetM: 1));
      expect(p.alongM, 299);
      expect(p.remainingM, closeTo(1, 0.5));
      expect(p.offsetM, 1);
      expect(p.isOffRoute, isFalse);
      expect(p.hasJoined, isTrue);
      expect(p.isFinished, isTrue);
    });
  });

  group('RouteTrack.headingAt', () {
    test('north along a route running north, east after its corner', () {
      final track = RouteTrack([at(0, 0), at(100, 0), at(100, 100)]);
      final north = track.headingAt(50);
      expect(north.x, closeTo(0, 1e-9));
      expect(north.y, closeTo(1, 1e-9));
      final east = track.headingAt(150);
      expect(east.x, closeTo(1, 1e-9));
      expect(east.y, closeTo(0, 1e-9));
    });
  });
}
