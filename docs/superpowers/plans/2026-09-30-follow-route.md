# Follow a Saved Route Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A rider can ride a saved route again: the old route is drawn as a semi-transparent reference on the live map with the rider's GPS position, progress, "X km to go" and an off-route banner. Recording the repeat ride is optional.

**Architecture:** A new pure domain unit (`RouteTrack` / `RouteProgress`, EXACT) projects positions onto the reference. A new process-lifetime `routeFollowProvider` (Riverpod `Notifier`) holds the reference + progress. In recording mode it reads the recorder's live position; in follow-only mode it subscribes to `LocationSource` itself. `RideTracker` and the recording pipeline are **not touched**. `LiveMap` gets optional reference layers. `ActiveRideScreen` shows them when a recording follow is active. A new `FollowRouteScreen` (`/follow`) covers follow-only.

**Tech Stack:** Flutter (Material 3), `flutter_riverpod` 3 (hand-written providers), `maplibre` 0.3.x, `go_router`, ARB l10n (en + de), `flutter_test` + `mocktail`.

**Spec:** `docs/specs/17-follow-route.md`

## Global Constraints

- **Hard invariant:** without a reference route set, every screen renders and behaves exactly as today. `RideTracker`, `RideRecordingController`, the foreground service, notifications and Live Activity stay unchanged. All existing tests stay green **without edits** (except the pure move in Task 4, whose existing Home tests must pass unchanged).
- Every new parameter on `LiveMap`, `RideMapArea`, `RideDetailDialog` and `HistoryRideCard` is optional and off by default.
- The reference is cleared on save / discard / skip / leaving the ride screen, on "End" in the follow screen, and at the start of every normal Home ride start.
- Off-route threshold: **30 m** (`followOffRouteThresholdM`). Finish: within **30 m** of the last point (`followFinishRadiusM`) **and** ≥ **90 %** along (`followFinishMinShare`). Look-ahead window **500 m** (`followLookAheadM`).
- Off-route feedback is a banner only (no vibration or sound). Follow-only GPS runs in the foreground only (paused when the app is backgrounded).
- Entry points are shown only when the ride has a route. The launcher ignores references with < 2 points.
- No user-facing literals: every string goes into **both** `lib/l10n/app_en.arb` and `lib/l10n/app_de.arb`. Colours come from `AppColors` tokens only (no new hex).
- Pure domain logic (`lib/domain/route_progress.dart`) uses **EXACT via `Skill({skill: "tdd-dart"})`** (`/test-list-dart` → `/red-dart` → `/green-dart` → `refactor` agent). Provider and widget tests use Red-Green-Refactor. `LiveMap` native-layer code gets tests alongside the implementation.
- Branch `phase/17-follow-route` off `main`. At the end: `flutter analyze` clean, `flutter test` green, rebase onto `main`, fast-forward `main`, delete the branch. No push without asking.
- Ghost rider, reverse riding and a DB schema change are **out of scope**.

## Review Focus

1. **Entry while a ride is already recording:** starting "Follow route" must not attach a reference to, or restart, the running ride. Expected: no dialog, go straight to `/ride`, no reference set. → test in Task 5.
2. **Abandoned "Record" start (back from the countdown), then a normal Home start:** expected: the normal ride has no reference. → test in Task 4.
3. **Location permission denied / GPS off in follow-only:** expected: the existing permission gate dialog, no navigation to `/follow`, no reference left set. → test in Task 5.
4. **Standing still with GPS jitter, or riding a few metres backwards:** expected: progress never decreases (holds), "X km to go" doesn't flicker upwards. → test in Task 1.
5. **Very inaccurate fixes (e.g. 80 m accuracy indoors) in follow-only:** expected: ignored, so the dot and progress don't jump. → test in Task 3.

---

## File Structure

| File | Status | Responsibility |
|---|---|---|
| `lib/domain/route_progress.dart` | create | `RouteTrack` (reference geometry, `locate`, `splitAt`) + `RouteProgress` value; pure, no Flutter |
| `test/domain/route_progress_test.dart` | create | EXACT tests |
| `lib/features/follow/route_follow_providers.dart` | create | `RouteFollowState`, `RouteFollowNotifier`, `routeFollowProvider` |
| `test/follow/route_follow_providers_test.dart` | create | provider tests |
| `lib/features/home/ride_start_flow.dart` | create | shared start sequence (moved out of `home_screen.dart`) |
| `lib/features/home/home_screen.dart` | modify | `_start` uses the shared flow + clears follow |
| `lib/features/follow/follow_route_launcher.dart` | create | record dialog + routing for both entry points |
| `test/follow/follow_route_launcher_test.dart` | create | launcher tests |
| `lib/features/history/ride_detail_dialog.dart` | modify | optional "Follow route" button |
| `lib/features/history/history_ride_card.dart` | modify | optional ⋮ "Follow route" entry |
| `lib/features/history/history_screen.dart` | modify | wires both entries to the launcher |
| `lib/map/live_map.dart` | modify | optional `reference` / `referenceProgressM` / `headingTrail` |
| `lib/features/active_ride/widgets/ride_chrome.dart` | modify | `RideMapArea` passes the new optional params through |
| `lib/features/follow/widgets/follow_chrome.dart` | create | `FollowRemainingLine`, `followBanner` helper |
| `lib/features/active_ride/active_ride_screen.dart` | modify | reference, banners, remaining line; clears follow on exit |
| `lib/features/follow/follow_route_screen.dart` | create | follow-only screen |
| `lib/features/shell/routes.dart`, `app_router.dart` | modify | `/follow` child route |
| `lib/l10n/app_en.arb`, `app_de.arb` | modify | new keys (added in the task that first uses them) |
| `CLAUDE.md`, `lib/map/CLAUDE.md`, `docs/specs/17-follow-route.md` | modify | docs (Task 9) |

---

### Task 0: Branch

- [ ] **Step 1: Create the feature branch**

```bash
cd /home/valiju/StudioProjects/retrail
git checkout main && git pull --ff-only 2>/dev/null; git checkout -b phase/17-follow-route
```

---

### Task 1: Domain — `RouteTrack.locate` (EXACT)

**Files:**
- Create: `lib/domain/route_progress.dart`
- Test: `test/domain/route_progress_test.dart`

**Interfaces:**
- Consumes: `LatLng` typedef (`({double lat, double lng})`) from `lib/domain/heading.dart`; `DistanceCalculator` / `HaversineDistanceCalculator` from `lib/domain/distance_calculator.dart`.
- Produces:
  - constants `followOffRouteThresholdM = 30`, `followFinishRadiusM = 30`, `followFinishMinShare = 0.9`, `followLookAheadM = 500`
  - `class RouteProgress { double alongM, remainingM, offsetM; bool isOffRoute, isFinished, hasJoined; }`
  - `class RouteTrack { RouteTrack(List<LatLng> points, {DistanceCalculator distance}); List<LatLng> points; List<double> cumulativeM; double get lengthM; RouteProgress? locate(LatLng position, {RouteProgress? previous}); }`

Methodology: invoke `Skill({skill: "tdd-dart"})`. Run `/test-list-dart` with the list below (all `skip:`), then activate them one at a time with `/red-dart` → `/green-dart`, and finish with the `refactor` agent. The test code below is the target content of the list. The implementation in Step 3 is the end state the green steps converge on.

- [ ] **Step 1: Write the test list**

```dart
// test/domain/route_progress_test.dart
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
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
      final loop =
          RouteTrack([at(0, 0), at(100, 0), at(100, 100), at(0, 100), at(0, 5)]);
      final p = loop.locate(at(0, 1))!;
      expect(p.alongM, lessThan(10));
      expect(p.isFinished, isFalse);
    });

    test('out-and-back on the same road: progress follows the return leg', () {
      final track = RouteTrack([at(0, 0), at(200, 0), at(0, 3)]);
      final p = walk(track, [
        at(50, 0), at(100, 0), at(150, 0), at(195, 0), at(199, 2),
        at(180, 3), at(150, 3),
      ])!;
      expect(p.alongM, closeTo(250, 3));
    });

    test('a crossing far ahead does not capture the position', () {
      // The last leg crosses the first one at (500, 0), 2100 m along.
      final track = RouteTrack([
        at(0, 0), at(1000, 0), at(1000, 300), at(500, 300), at(500, -300),
      ]);
      final p =
          walk(track, [at(400, 0), at(450, 0), at(500, 0), at(550, 0)])!;
      expect(p.alongM, closeTo(550, 1));
    });

    test('first fix exactly on a crossing takes the earlier pass', () {
      final track = RouteTrack([
        at(0, 0), at(1000, 0), at(1000, 300), at(500, 300), at(500, -300),
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
  });
}
```

- [ ] **Step 2: Run to verify the first activated test fails**

Run: `flutter test test/domain/route_progress_test.dart`
Expected: compile error (`route_progress.dart` not found), then per `/red-dart` an assertion failure for each newly activated test.

- [ ] **Step 3: Implementation (end state)**

```dart
// lib/domain/route_progress.dart
import 'dart:math' as math;

import 'distance_calculator.dart';
import 'heading.dart' show LatLng;

/// Farther than this from the reference route counts as off route.
const double followOffRouteThresholdM = 30;

/// Within this of the route's last point (and far enough along, see
/// [followFinishMinShare]) the finish counts as reached.
const double followFinishRadiusM = 30;

/// Share of the route that must be behind the rider before the finish counts.
/// On a loop the start lies within [followFinishRadiusM] of the finish.
const double followFinishMinShare = 0.9;

/// While on route, only this much route ahead of the last progress is
/// searched, so a crossing or a parallel leg further on can't capture the
/// position.
const double followLookAheadM = 500;

/// On-route candidates farther apart than this along the route are separate
/// passes of the route past the rider (loop start vs finish, out-and-back legs).
const double _passGapM = 2 * followOffRouteThresholdM;

/// Candidates whose offsets differ by at most this are a tie; the one less far
/// along the route wins.
const double _offsetTieM = 1;

/// Where the rider is relative to the reference route.
class RouteProgress {
  const RouteProgress({
    required this.alongM,
    required this.remainingM,
    required this.offsetM,
    required this.isOffRoute,
    required this.isFinished,
    required this.hasJoined,
  });

  /// Distance along the route to the rider's projected position.
  final double alongM;
  final double remainingM;

  /// Distance from the rider to the route.
  final double offsetM;
  final bool isOffRoute;
  final bool isFinished;

  /// True once the rider has been on the route at least once. Before that the
  /// UI shows "X to the route" instead of "Off route".
  final bool hasJoined;

  @override
  String toString() => 'RouteProgress(along: $alongM, remaining: $remainingM, '
      'offset: $offsetM, off: $isOffRoute, finished: $isFinished, '
      'joined: $hasJoined)';
}

/// A reference route with its cumulative distances, locating positions on it.
class RouteTrack {
  RouteTrack(List<LatLng> points,
      {DistanceCalculator distance = const HaversineDistanceCalculator()})
      : points = List.unmodifiable(points),
        _distance = distance,
        cumulativeM = List.unmodifiable(_cumulative(points, distance));

  final List<LatLng> points;

  /// Distance from the first point to each point.
  final List<double> cumulativeM;
  final DistanceCalculator _distance;

  double get lengthM => cumulativeM.isEmpty ? 0 : cumulativeM.last;

  static List<double> _cumulative(List<LatLng> points, DistanceCalculator d) {
    final out = <double>[];
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      if (i > 0) {
        final a = points[i - 1], b = points[i];
        sum += d.distanceBetween(a.lat, a.lng, b.lat, b.lng);
      }
      out.add(sum);
    }
    return out;
  }

  /// Projects [position] onto the route. [previous] is the last result: while
  /// on route only the window ahead of it is searched and progress never
  /// decreases; the first fix and a rejoin search the whole route. Null for a
  /// route without length.
  RouteProgress? locate(LatLng position, {RouteProgress? previous}) {
    if (lengthM <= 0) return null;
    if (previous != null && previous.hasJoined && !previous.isOffRoute) {
      final best = _closest(_candidates(position, previous.alongM,
          math.min(lengthM, previous.alongM + followLookAheadM)));
      if (best != null && best.offsetM <= followOffRouteThresholdM) {
        return _onRoute(position, best);
      }
    }
    final all = _candidates(position, 0, lengthM);
    final onRoute =
        all.where((c) => c.offsetM <= followOffRouteThresholdM).toList();
    if (onRoute.isEmpty) {
      final along = previous?.alongM ?? 0;
      return RouteProgress(
        alongM: along,
        remainingM: lengthM - along,
        offsetM: all.map((c) => c.offsetM).reduce(math.min),
        isOffRoute: true,
        isFinished: false,
        hasJoined: previous?.hasJoined ?? false,
      );
    }
    final passes = _passes(onRoute);
    final pick = previous != null && previous.hasJoined
        ? passes.firstWhere((c) => c.alongM >= previous.alongM,
            orElse: () => passes.first)
        : passes.first;
    return _onRoute(position, pick);
  }

  RouteProgress _onRoute(LatLng position, _Candidate c) {
    final end = points.last;
    final toEnd =
        _distance.distanceBetween(position.lat, position.lng, end.lat, end.lng);
    return RouteProgress(
      alongM: c.alongM,
      remainingM: math.max(0, lengthM - c.alongM),
      offsetM: c.offsetM,
      isOffRoute: false,
      isFinished: toEnd <= followFinishRadiusM &&
          c.alongM >= followFinishMinShare * lengthM,
      hasJoined: true,
    );
  }

  /// The nearest point of each segment overlapping [fromM]..[toM] (clamped to
  /// that range), with its distance along the route and to [p].
  List<_Candidate> _candidates(LatLng p, double fromM, double toM) {
    final out = <_Candidate>[];
    for (var i = 0; i < points.length - 1; i++) {
      final start = cumulativeM[i];
      final len = cumulativeM[i + 1] - start;
      if (len <= 0 || cumulativeM[i + 1] < fromM || start > toM) continue;
      final tMin = math.max(0.0, (fromM - start) / len);
      final tMax = math.min(1.0, (toM - start) / len);
      if (tMin > tMax) continue;
      final t = _projectT(points[i], points[i + 1], p).clamp(tMin, tMax);
      final q = _lerp(points[i], points[i + 1], t);
      out.add(_Candidate(
        alongM: start + t * len,
        offsetM: _distance.distanceBetween(p.lat, p.lng, q.lat, q.lng),
      ));
    }
    return out;
  }

  /// Segment parameter of [p]'s perpendicular foot on a→b, in a local
  /// equirectangular frame (longitude scaled by cos(latitude)).
  static double _projectT(LatLng a, LatLng b, LatLng p) {
    final k = math.cos(a.lat * math.pi / 180);
    final bx = (b.lng - a.lng) * k, by = b.lat - a.lat;
    final px = (p.lng - a.lng) * k, py = p.lat - a.lat;
    final dd = bx * bx + by * by;
    return dd == 0 ? 0 : (px * bx + py * by) / dd;
  }

  static LatLng _lerp(LatLng a, LatLng b, double t) =>
      (lat: a.lat + (b.lat - a.lat) * t, lng: a.lng + (b.lng - a.lng) * t);

  static _Candidate? _closest(Iterable<_Candidate> cs) {
    _Candidate? best;
    for (final c in cs) {
      if (best == null ||
          c.offsetM < best.offsetM - _offsetTieM ||
          (c.offsetM <= best.offsetM + _offsetTieM && c.alongM < best.alongM)) {
        best = c;
      }
    }
    return best;
  }

  /// Groups [onRoute] into passes (along-gap > [_passGapM]) and returns each
  /// pass's closest candidate, in route order.
  static List<_Candidate> _passes(List<_Candidate> onRoute) {
    final sorted = [...onRoute]..sort((a, b) => a.alongM.compareTo(b.alongM));
    final passes = <_Candidate>[];
    var group = <_Candidate>[sorted.first];
    for (final c in sorted.skip(1)) {
      if (c.alongM - group.last.alongM > _passGapM) {
        passes.add(_closest(group)!);
        group = [c];
      } else {
        group.add(c);
      }
    }
    passes.add(_closest(group)!);
    return passes;
  }
}

class _Candidate {
  const _Candidate({required this.alongM, required this.offsetM});
  final double alongM;
  final double offsetM;
}
```

- [ ] **Step 4: Run the tests**

Run: `flutter test test/domain/route_progress_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/route_progress.dart test/domain/route_progress_test.dart
git commit -m "feat(domain): locate a position on a reference route (spec 17)"
```

---

### Task 2: Domain — `RouteTrack.splitAt` (EXACT)

**Files:**
- Modify: `lib/domain/route_progress.dart`
- Test: `test/domain/route_progress_test.dart`

**Interfaces:**
- Produces: `typedef RouteSplit = ({List<LatLng> done, List<LatLng> ahead});` and `RouteSplit RouteTrack.splitAt(double alongM)`. Used by `LiveMap` (Task 6) to grey out the ridden part.

Same EXACT flow (`/test-list-dart` → `/red-dart` → `/green-dart` → refactor).

- [ ] **Step 1: Add the test list** (append a group inside `main()`)

```dart
  group('RouteTrack.splitAt', () {
    void expectPoint(LatLng actual, LatLng expected) {
      expect(actual.lat, closeTo(expected.lat, 1e-9));
      expect(actual.lng, closeTo(expected.lng, 1e-9));
    }

    test('mid-segment: both halves share the cut point', () {
      final s = RouteTrack(_straight).splitAt(150);
      expect(s.done.length, 3);
      expect(s.ahead.length, 3);
      expectPoint(s.done.last, at(150, 0));
      expectPoint(s.ahead.first, at(150, 0));
      expectPoint(s.ahead.last, at(300, 0));
    });

    test('at a vertex: no duplicated point', () {
      final s = RouteTrack(_straight).splitAt(100);
      expect(s.done.length, 2);
      expect(s.ahead.length, 3);
      expectPoint(s.ahead.first, at(100, 0));
    });

    test('at or before the start nothing is done', () {
      final s = RouteTrack(_straight).splitAt(0);
      expect(s.done, isEmpty);
      expect(s.ahead.length, 4);
    });

    test('at or past the end everything is done', () {
      final s = RouteTrack(_straight).splitAt(400);
      expect(s.done.length, 4);
      expect(s.ahead, isEmpty);
    });

    test('a single-point route is all ahead', () {
      final s = RouteTrack([at(0, 0)]).splitAt(10);
      expect(s.done, isEmpty);
      expect(s.ahead.length, 1);
    });
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/domain/route_progress_test.dart`
Expected: compile error `splitAt` not defined, then assertion failures while activating.

- [ ] **Step 3: Implementation (end state)** — add to `route_progress.dart`

```dart
/// A route cut at a distance along it: the part behind and the part ahead,
/// sharing the cut point.
typedef RouteSplit = ({List<LatLng> done, List<LatLng> ahead});
```

and inside `RouteTrack`:

```dart
  /// Cuts the route [alongM] metres from the start (clamped to the route).
  RouteSplit splitAt(double alongM) {
    if (lengthM <= 0 || alongM <= 0) return (done: const [], ahead: points);
    if (alongM >= lengthM) return (done: points, ahead: const []);
    var i = 0;
    while (i < points.length - 2 && cumulativeM[i + 1] < alongM) {
      i++;
    }
    final len = cumulativeM[i + 1] - cumulativeM[i];
    final t = len == 0 ? 0.0 : (alongM - cumulativeM[i]) / len;
    final cut = _lerp(points[i], points[i + 1], t);
    return (
      done: [...points.sublist(0, i + 1), if (t > 0) cut],
      ahead: [if (t < 1) cut, ...points.sublist(i + 1)],
    );
  }
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/domain/route_progress_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/domain/route_progress.dart test/domain/route_progress_test.dart
git commit -m "feat(domain): split a reference route at the rider's progress"
```

---

### Task 3: `routeFollowProvider` (Red-Green-Refactor)

**Files:**
- Create: `lib/features/follow/route_follow_providers.dart`
- Test: `test/follow/route_follow_providers_test.dart`

**Interfaces:**
- Consumes: `RouteTrack`, `RouteProgress` (Task 1); `rideTrackingStateProvider`, `locationSourceProvider`, `distanceCalculatorProvider` (`lib/tracking/tracking_providers.dart`); `LocationFix` (`lib/tracking/location_fix.dart`); `LocationSource` (`lib/tracking/location_source.dart`).
- Produces:
  - `const double followMaxFixAccuracyM = 30;`
  - `class RouteFollowState { RouteTrack track; bool recording; String? rideTitle; RouteProgress? progress; LocationFix? lastFix; List<LatLng> trail; bool locationServiceEnabled; }`
  - `class RouteFollowNotifier extends Notifier<RouteFollowState?>` with `void start({required List<LatLng> reference, String? rideTitle, required bool recording})`, `void stop()`, `Future<void> resumeFeed()`, `void pauseFeed()`, `void onFix(LocationFix fix)`
  - `final routeFollowProvider = NotifierProvider<RouteFollowNotifier, RouteFollowState?>(...)`

- [ ] **Step 1: Write the failing tests**

```dart
// test/follow/route_follow_providers_test.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/tracking/location_fix.dart';
import 'package:retrail/tracking/location_source.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';

class FakeLocationSource implements LocationSource {
  final fixCtrl = StreamController<LocationFix>.broadcast();
  final serviceCtrl = StreamController<bool>.broadcast();
  LocationFix? last;
  @override
  Stream<LocationFix> get fixes => fixCtrl.stream;
  @override
  Stream<bool> get serviceEnabled => serviceCtrl.stream;
  @override
  Future<LocationFix?> lastKnown() async => last;
}

LocationFix fix(double lat, double lng, {double accuracy = 5}) => LocationFix(
      latitude: lat,
      longitude: lng,
      accuracy: accuracy,
      hasSpeed: false,
      speed: 0,
      elapsedRealtimeNanos: 0,
    );

// ~111 m per 0.001° latitude.
const _ref = [(lat: 48.0, lng: 11.0), (lat: 48.001, lng: 11.0), (lat: 48.002, lng: 11.0)];

void main() {
  late FakeLocationSource source;
  late StreamController<RideTrackingState> tracker;
  late ProviderContainer c;

  setUp(() {
    source = FakeLocationSource();
    tracker = StreamController<RideTrackingState>.broadcast();
    c = ProviderContainer(overrides: [
      locationSourceProvider.overrideWithValue(source),
      rideTrackingStateProvider.overrideWith((ref) => tracker.stream),
    ]);
    c.listen(routeFollowProvider, (_, _) {});
  });
  tearDown(() => c.dispose());

  Future<void> flush() => Future<void>.delayed(Duration.zero);
  RouteFollowNotifier notifier() => c.read(routeFollowProvider.notifier);

  test('starts without a reference', () {
    expect(c.read(routeFollowProvider), isNull);
  });

  test('start sets reference, title and mode; stop clears it', () {
    notifier().start(reference: _ref, rideTitle: 'Rhein', recording: false);
    final s = c.read(routeFollowProvider)!;
    expect(s.track.points, _ref);
    expect(s.rideTitle, 'Rhein');
    expect(s.recording, isFalse);
    expect(s.progress, isNull);
    notifier().stop();
    expect(c.read(routeFollowProvider), isNull);
  });

  test('follow-only: feed fixes update progress, position and trail', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    final s = c.read(routeFollowProvider)!;
    expect(s.progress!.alongM, closeTo(111.2, 1));
    expect(s.lastFix!.latitude, 48.001);
    expect(s.trail, [(lat: 48.001, lng: 11.0)]);
  });

  test('follow-only: the last known fix seeds the position', () async {
    source.last = fix(48.0005, 11.0);
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    expect(c.read(routeFollowProvider)!.progress!.alongM, closeTo(55.6, 1));
  });

  test('inaccurate fixes are ignored', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.fixCtrl.add(fix(48.001, 11.0, accuracy: 80));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
  });

  test('location services off/on is reflected', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    source.serviceCtrl.add(false);
    await flush();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isFalse);
    source.serviceCtrl.add(true);
    await flush();
    expect(c.read(routeFollowProvider)!.locationServiceEnabled, isTrue);
  });

  test('pauseFeed stops listening until resumed', () async {
    notifier().start(reference: _ref, recording: false);
    await notifier().resumeFeed();
    notifier().pauseFeed();
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
    await notifier().resumeFeed();
    source.fixCtrl.add(fix(48.001, 11.0));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNotNull);
  });

  test('a stop during resumeFeed does not leave a subscription', () async {
    notifier().start(reference: _ref, recording: false);
    final pending = notifier().resumeFeed();
    notifier().stop();
    await pending;
    expect(source.fixCtrl.hasListener, isFalse);
  });

  test('recording: the recorder position drives progress', () async {
    notifier().start(reference: _ref, recording: true);
    tracker.add(RideTrackingState(isTracking: true, location: fix(48.001, 11.0)));
    await flush();
    expect(c.read(routeFollowProvider)!.progress!.alongM, closeTo(111.2, 1));
  });

  test('recording mode never opens its own GPS feed', () async {
    notifier().start(reference: _ref, recording: true);
    await notifier().resumeFeed();
    expect(source.fixCtrl.hasListener, isFalse);
  });

  test('follow-only ignores the recorder position', () async {
    notifier().start(reference: _ref, recording: false);
    tracker.add(RideTrackingState(isTracking: true, location: fix(48.001, 11.0)));
    await flush();
    expect(c.read(routeFollowProvider)!.lastFix, isNull);
  });
}
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/follow/route_follow_providers_test.dart`
Expected: FAIL — compile error, `route_follow_providers.dart` not found.

- [ ] **Step 3: Implement**

```dart
// lib/features/follow/route_follow_providers.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/heading.dart' show LatLng;
import '../../domain/route_progress.dart';
import '../../tracking/location_fix.dart';
import '../../tracking/tracking_providers.dart';

/// Fixes less accurate than this don't move the follow position (the
/// follow-only feed doesn't pass through the recorder's GPS filter).
const double followMaxFixAccuracyM = 30;

/// Recent positions kept for the heading-up camera in follow-only mode.
const int _trailLength = 30;

/// A reference route being followed (Spec 17), with the rider's progress.
class RouteFollowState {
  const RouteFollowState({
    required this.track,
    required this.recording,
    this.rideTitle,
    this.progress,
    this.lastFix,
    this.trail = const [],
    this.locationServiceEnabled = true,
  });

  final RouteTrack track;

  /// True when the repeat ride is being recorded (position from the recorder);
  /// false for follow-only (own foreground GPS feed).
  final bool recording;
  final String? rideTitle;
  final RouteProgress? progress;
  final LocationFix? lastFix;

  /// Recent positions, oldest first — the follow-only map's heading source.
  final List<LatLng> trail;
  final bool locationServiceEnabled;

  RouteFollowState copyWith({
    RouteProgress? progress,
    LocationFix? lastFix,
    List<LatLng>? trail,
    bool? locationServiceEnabled,
  }) =>
      RouteFollowState(
        track: track,
        recording: recording,
        rideTitle: rideTitle,
        progress: progress ?? this.progress,
        lastFix: lastFix ?? this.lastFix,
        trail: trail ?? this.trail,
        locationServiceEnabled:
            locationServiceEnabled ?? this.locationServiceEnabled,
      );
}

/// Holds the followed reference (null = none, today's behaviour). Never
/// touches the recorder: in recording mode it only reads its live position.
class RouteFollowNotifier extends Notifier<RouteFollowState?> {
  StreamSubscription<LocationFix>? _fixSub;
  StreamSubscription<bool>? _serviceSub;

  /// Bumped on every feed cancel so a [resumeFeed] still awaiting its seed
  /// can tell it was stopped meanwhile.
  int _feedEpoch = 0;

  @override
  RouteFollowState? build() {
    ref.onDispose(_cancelFeed);
    ref.listen(rideTrackingStateProvider, (_, next) {
      final fix = next.asData?.value.location;
      if (fix != null && state?.recording == true) onFix(fix);
    });
    return null;
  }

  void start({
    required List<LatLng> reference,
    String? rideTitle,
    required bool recording,
  }) {
    _cancelFeed();
    state = RouteFollowState(
      track: RouteTrack(reference, distance: ref.read(distanceCalculatorProvider)),
      recording: recording,
      rideTitle: rideTitle,
    );
  }

  void stop() {
    _cancelFeed();
    state = null;
  }

  /// Follow-only: starts the foreground GPS feed (seeded with the last known
  /// fix). No-op in recording mode or when already running.
  Future<void> resumeFeed() async {
    final s = state;
    if (s == null || s.recording || _fixSub != null) return;
    final epoch = ++_feedEpoch;
    final source = ref.read(locationSourceProvider);
    final seed = await source.lastKnown();
    if (epoch != _feedEpoch || state == null) return;
    if (seed != null) onFix(seed);
    _fixSub = source.fixes.listen(onFix, onError: (Object _) {});
    _serviceSub = source.serviceEnabled.listen((on) {
      final cur = state;
      if (cur != null) state = cur.copyWith(locationServiceEnabled: on);
    });
  }

  /// Follow-only: stops the GPS feed (app backgrounded). Progress is kept.
  void pauseFeed() => _cancelFeed();

  void onFix(LocationFix fix) {
    final s = state;
    if (s == null || fix.accuracy > followMaxFixAccuracyM) return;
    final p = (lat: fix.latitude, lng: fix.longitude);
    final trail = [...s.trail, p];
    state = s.copyWith(
      progress: s.track.locate(p, previous: s.progress),
      lastFix: fix,
      trail: trail.length > _trailLength
          ? trail.sublist(trail.length - _trailLength)
          : trail,
    );
  }

  void _cancelFeed() {
    _feedEpoch++;
    _fixSub?.cancel();
    _serviceSub?.cancel();
    _fixSub = null;
    _serviceSub = null;
  }
}

final routeFollowProvider =
    NotifierProvider<RouteFollowNotifier, RouteFollowState?>(
        RouteFollowNotifier.new);
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/follow/route_follow_providers_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/follow/route_follow_providers.dart test/follow/route_follow_providers_test.dart
git commit -m "feat(follow): route-follow provider with recording and follow-only feeds"
```

---

### Task 4: Shared ride start flow + Home clears a leftover reference

A pure move of Home's start sequence into a reusable function (so "Follow route → Record" starts rides exactly like Home), plus one new Home behaviour.

**Files:**
- Create: `lib/features/home/ride_start_flow.dart`
- Modify: `lib/features/home/home_screen.dart` (`_start`, delete `_proceed`, `_showGateBlocked`, `_confirmOffline`; drop the imports that become unused)
- Test: `test/home/home_screen_test.dart`

**Interfaces:**
- Consumes: `routeFollowProvider` (Task 3).
- Produces: `Future<bool> runRideStartFlow(BuildContext context, WidgetRef ref, {VoidCallback? beforeCountdown})` (true = countdown opened; `beforeCountdown` runs only once the gate granted, right before navigating) and `Future<void> showPermissionGateBlocked(BuildContext context, WidgetRef ref, LocationStartAction action)`.

- [ ] **Step 1: Write the failing test** (append in `home_screen_test.dart`'s `main()`; add imports `package:retrail/features/follow/route_follow_providers.dart` and `package:flutter_riverpod/flutter_riverpod.dart` if missing)

```dart
  testWidgets(
      'Start clears a reference left over from an abandoned follow start',
      (tester) async {
    await pumpHome(tester);
    final container =
        ProviderScope.containerOf(tester.element(find.text('Start tracking')));
    container.read(routeFollowProvider.notifier).start(
        reference: const [(lat: 48.0, lng: 11.0), (lat: 48.001, lng: 11.0)],
        recording: true);
    await tester.tap(find.text('Start tracking'));
    await _settle(tester);
    expect(find.text('GET READY'), findsOneWidget);
    expect(container.read(routeFollowProvider), isNull);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/home/home_screen_test.dart --plain-name "abandoned follow start"`
Expected: FAIL — `Expected: null, Actual: <Instance of 'RouteFollowState'>`.

- [ ] **Step 3: Create `ride_start_flow.dart`** (bodies moved verbatim from `_HomeScreenState`)

```dart
// lib/features/home/ride_start_flow.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/widgets/stacked_dialog_actions.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/location_permission.dart';
import '../../tracking/permission_gate_dialog.dart';
import '../../tracking/tracking_providers.dart';
import '../shell/routes.dart';
import 'home_providers.dart';

/// The Start-tracking sequence shared by Home and "Follow route → Record":
/// commits the pending activity, asks before an offline start, resolves
/// location (and notification) permission up front — before the countdown,
/// mirroring the original `HomePage` — and opens the countdown when granted.
/// A blocked gate surfaces the rationale / enable-location prompt instead.
/// [beforeCountdown] runs only when the countdown is about to open (the
/// follow launcher sets its reference there, so a blocked or declined start
/// never leaves one behind). Returns whether the countdown was opened.
Future<bool> runRideStartFlow(BuildContext context, WidgetRef ref,
    {VoidCallback? beforeCountdown}) async {
  ref.read(homeControllerProvider).beginTracking();
  final online = ref.read(isOnlineProvider).asData?.value ?? true;
  if (!online && !await _confirmOffline(context)) return false;
  if (!context.mounted) return false;
  final action = await ref.read(rideRecordingControllerProvider).prepare();
  if (!context.mounted) return false;
  if (action == LocationStartAction.proceed) {
    beforeCountdown?.call();
    context.go(AppRoutes.timer);
    return true;
  }
  await showPermissionGateBlocked(context, ref, action);
  return false;
}

Future<void> showPermissionGateBlocked(
    BuildContext context, WidgetRef ref, LocationStartAction action) async {
  final recording = ref.read(rideRecordingControllerProvider);
  await showDialog<void>(
    context: context,
    builder: (c) => PermissionGateDialog(
      action: action,
      onOpenSettings: () {
        Navigator.pop(c);
        action == LocationStartAction.openLocationSettings
            ? recording.openLocationSettings()
            : recording.openAppSettings();
      },
      onDismiss: () => Navigator.pop(c),
    ),
  );
}

Future<bool> _confirmOffline(BuildContext context) async {
  final l10n = AppLocalizations.of(context);
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.offlineTrackingTitle),
      content: Text(l10n.offlineTrackingBody),
      actions: [
        StackedDialogActions(
          primaryLabel: l10n.offlineTrackingConfirm,
          onPrimary: () => Navigator.pop(c, true),
          secondaryLabel: l10n.actionSkip,
          onSecondary: () => Navigator.pop(c, false),
        ),
      ],
    ),
  );
  return confirmed == true;
}
```

- [ ] **Step 4: Replace Home's `_start`** and delete `_proceed`, `_showGateBlocked`, `_confirmOffline` from `_HomeScreenState`

```dart
  Future<void> _start() async {
    if (ref.read(isTrackingProvider)) {
      context.go(AppRoutes.ride);
      return;
    }
    // A normal ride never inherits a reference left over from an abandoned
    // "Follow route → Record" start (e.g. back from the countdown).
    ref.read(routeFollowProvider.notifier).stop();
    await runRideStartFlow(context, ref);
  }
```

Add imports `import '../follow/route_follow_providers.dart';` and `import 'ride_start_flow.dart';`. Run `flutter analyze lib/features/home` and delete the imports it reports as unused (expected: `stacked_dialog_actions.dart`, `permission_gate_dialog.dart`, possibly `location_permission.dart` and `connectivity_providers.dart` — keep any still used elsewhere in the file).

- [ ] **Step 5: Run the Home tests (existing ones must pass unchanged)**

Run: `flutter test test/home/`
Expected: all PASS, including the new test.

- [ ] **Step 6: Commit**

```bash
git add lib/features/home/ride_start_flow.dart lib/features/home/home_screen.dart test/home/home_screen_test.dart
git commit -m "refactor(home): share the ride start flow; clear leftover follow reference"
```

---

### Task 5: Follow launcher (record dialog + routing), `/follow` route stub

**Files:**
- Create: `lib/features/follow/follow_route_launcher.dart`
- Create: `lib/features/follow/follow_route_screen.dart` (minimal stub here, full screen in Task 8)
- Modify: `lib/features/shell/routes.dart`, `lib/features/shell/app_router.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`
- Test: `test/follow/follow_route_launcher_test.dart`

**Interfaces:**
- Consumes: `routeFollowProvider` (Task 3), `runRideStartFlow` / `showPermissionGateBlocked` (Task 4), `isTrackingProvider`, `rideRecordingControllerProvider`.
- Produces: `Future<void> launchFollowRoute(BuildContext context, WidgetRef ref, {required List<LatLng> reference, String? rideTitle})`; `AppRoutes.follow = '/follow'`; `class FollowRouteScreen extends ConsumerStatefulWidget`.

- [ ] **Step 1: Add the ARB keys** (both files; keep them together near the other ride keys)

`app_en.arb`:
```json
  "followRouteAction": "Follow route",
  "followRouteRecordTitle": "Record this ride?",
  "followRouteRecordBody": "The route is shown on the map either way. Record it to save this ride to your history.",
  "followRouteRecordConfirm": "Record",
  "followRouteJustFollow": "Just follow",
```
`app_de.arb`:
```json
  "followRouteAction": "Strecke nachfahren",
  "followRouteRecordTitle": "Fahrt aufzeichnen?",
  "followRouteRecordBody": "Die Strecke wird in beiden Fällen auf der Karte angezeigt. Zeichne sie auf, um die Fahrt im Verlauf zu speichern.",
  "followRouteRecordConfirm": "Aufzeichnen",
  "followRouteJustFollow": "Nur folgen",
```
Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

```dart
// test/follow/follow_route_launcher_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/features/follow/follow_route_launcher.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/l10n/app_localizations.dart';
import 'package:retrail/tracking/location_permission.dart';
import 'package:retrail/tracking/tracking_providers.dart';

import '../home/home_test_helpers.dart';

const _ref = [(lat: 48.0, lng: 11.0), (lat: 48.001, lng: 11.0)];

void main() {
  late FakeRecordingController recording;
  late ProviderContainer container;

  Future<void> pumpLauncher(WidgetTester tester,
      {bool tracking = false, List<({double lat, double lng})> ref = _ref}) async {
    final env = await buildHomeEnv(initialPrefs: {'onboarding_done': true});
    addTearDown(env.db.close);
    recording = makeFakeRecording(env.db);
    final router = GoRouter(initialLocation: '/', routes: [
      GoRoute(
        path: '/',
        builder: (c, s) => Consumer(
          builder: (context, ref2, _) => TextButton(
            onPressed: () =>
                launchFollowRoute(context, ref2, reference: ref, rideTitle: 'Rhein'),
            child: const Text('go'),
          ),
        ),
      ),
      GoRoute(path: '/timer', builder: (c, s) => const Text('TIMER')),
      GoRoute(path: '/ride', builder: (c, s) => const Text('RIDE')),
      GoRoute(path: '/follow', builder: (c, s) => const Text('FOLLOW')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(env.db),
        preferencesRepositoryProvider.overrideWithValue(env.prefs),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        isTrackingProvider.overrideWithValue(tracking),
        ...activeRideTestOverrides(env.db, recording: recording),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    container = ProviderScope.containerOf(tester.element(find.text('go')));
  }

  testWidgets('asks whether to record', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Record this ride?'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
    expect(find.text('Just follow'), findsOneWidget);
  });

  testWidgets('Record sets a recording reference and opens the countdown',
      (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('TIMER'), findsOneWidget);
    final s = container.read(routeFollowProvider)!;
    expect(s.recording, isTrue);
    expect(s.rideTitle, 'Rhein');
  });

  testWidgets('Just follow sets a follow-only reference and opens /follow',
      (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just follow'));
    await tester.pumpAndSettle();
    expect(find.text('FOLLOW'), findsOneWidget);
    expect(container.read(routeFollowProvider)!.recording, isFalse);
    expect(recording.calls, contains('prepare'));
  });

  testWidgets('dismissing the dialog does nothing', (tester) async {
    await pumpLauncher(tester);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();
    expect(find.text('go'), findsOneWidget);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('blocked permission: gate dialog, no navigation, no reference',
      (tester) async {
    await pumpLauncher(tester);
    recording.prepareResult = LocationStartAction.showRationale;
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Just follow'));
    await tester.pumpAndSettle();
    expect(find.text('Location needed'), findsOneWidget);
    expect(find.text('FOLLOW'), findsNothing);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('blocked permission on Record leaves no reference',
      (tester) async {
    await pumpLauncher(tester);
    recording.prepareResult = LocationStartAction.showRationale;
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Record'));
    await tester.pumpAndSettle();
    expect(find.text('TIMER'), findsNothing);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('while a ride is recording: straight to it, no reference',
      (tester) async {
    await pumpLauncher(tester, tracking: true);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Record this ride?'), findsNothing);
    expect(find.text('RIDE'), findsOneWidget);
    expect(container.read(routeFollowProvider), isNull);
  });

  testWidgets('a reference with fewer than 2 points is ignored', (tester) async {
    await pumpLauncher(tester, ref: const [(lat: 48.0, lng: 11.0)]);
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(find.text('Record this ride?'), findsNothing);
  });
}
```

> `buildHomeEnv`, `makeFakeRecording`, `activeRideTestOverrides` and `FakeRecordingController` (`prepareResult`, `calls`) come from `test/home/home_test_helpers.dart`, the same helpers the Home start tests use. The blocked-permission tests assert while the gate dialog is still open — the reference must already be absent then, which is why the launcher sets it only via `beforeCountdown`.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/follow/follow_route_launcher_test.dart`
Expected: FAIL — `follow_route_launcher.dart` not found.

- [ ] **Step 4: Implement the launcher, route and stub screen**

```dart
// lib/features/follow/follow_route_launcher.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/stacked_dialog_actions.dart';
import '../../domain/heading.dart' show LatLng;
import '../../l10n/app_localizations.dart';
import '../../tracking/location_permission.dart';
import '../../tracking/tracking_providers.dart';
import '../home/ride_start_flow.dart';
import '../shell/routes.dart';
import 'route_follow_providers.dart';

enum _FollowChoice { record, followOnly }

/// Starts following [reference] (Spec 17): asks whether to record, then either
/// runs the normal ride start (countdown → ride, with the reference) or opens
/// the follow-only screen. While a ride is already recording it just returns
/// to that ride, without a reference.
Future<void> launchFollowRoute(
  BuildContext context,
  WidgetRef ref, {
  required List<LatLng> reference,
  String? rideTitle,
}) async {
  if (reference.length < 2) return;
  if (ref.read(isTrackingProvider)) {
    context.go(AppRoutes.ride);
    return;
  }
  final l10n = AppLocalizations.of(context);
  final choice = await showDialog<_FollowChoice>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.followRouteRecordTitle),
      content: Text(l10n.followRouteRecordBody),
      actions: [
        StackedDialogActions(
          primaryLabel: l10n.followRouteRecordConfirm,
          onPrimary: () => Navigator.pop(c, _FollowChoice.record),
          secondaryLabel: l10n.followRouteJustFollow,
          onSecondary: () => Navigator.pop(c, _FollowChoice.followOnly),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final follow = ref.read(routeFollowProvider.notifier);
  switch (choice) {
    case _FollowChoice.record:
      await runRideStartFlow(context, ref,
          beforeCountdown: () => follow.start(
              reference: reference, rideTitle: rideTitle, recording: true));
    case _FollowChoice.followOnly:
      final action = await ref.read(rideRecordingControllerProvider).prepare();
      if (!context.mounted) return;
      if (action != LocationStartAction.proceed) {
        await showPermissionGateBlocked(context, ref, action);
        return;
      }
      follow.start(reference: reference, rideTitle: rideTitle, recording: false);
      context.go(AppRoutes.follow);
  }
}
```

`routes.dart` — add:
```dart
  static const follow = '/follow';
```

`app_router.dart` — add the import `import '../follow/follow_route_screen.dart';` and a child route after `ride`:
```dart
          GoRoute(
              path: 'follow',
              pageBuilder: (c, s) => _rideEnter(const FollowRouteScreen(), s)),
```

Stub screen (replaced in Task 8):
```dart
// lib/features/follow/follow_route_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Follow-only mode (Spec 17 §E2). Filled in by the follow-screen task.
class FollowRouteScreen extends ConsumerStatefulWidget {
  const FollowRouteScreen({super.key});

  @override
  ConsumerState<FollowRouteScreen> createState() => _FollowRouteScreenState();
}

class _FollowRouteScreenState extends ConsumerState<FollowRouteScreen> {
  @override
  Widget build(BuildContext context) => const Scaffold();
}
```

- [ ] **Step 5: Run tests**

Run: `flutter test test/follow/ test/shell/`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/follow lib/features/shell lib/l10n test/follow
git commit -m "feat(follow): record-or-follow launcher and /follow route"
```

---

### Task 6: Entry points — detail dialog button + history card ⋮ entry

**Files:**
- Modify: `lib/features/history/ride_detail_dialog.dart` (constructor + bottom action row, ~line 243)
- Modify: `lib/features/history/history_ride_card.dart` (constructor, `_OverflowMenu` ~line 335, its call ~line 159)
- Modify: `lib/features/history/history_screen.dart` (`_openDetail` ~line 245, card construction ~line 395)
- Test: `test/history/history_dialogs_test.dart`, `test/history/history_screen_test.dart`

**Interfaces:**
- Consumes: `launchFollowRoute` (Task 5), `l10n.followRouteAction` (Task 5).
- Produces: `RideDetailDialog({..., VoidCallback? onFollowRoute})`, `HistoryRideCard({..., VoidCallback? onFollowRoute})`.

Icon for both: `Icons.route`.

- [ ] **Step 1: Write the failing tests**

In `history_dialogs_test.dart`, inside the `RideDetailDialog` group (reuse the file's `_host`, `_ride()` helpers; add a two-trackpoint list the way the existing fitBounds test builds one):

```dart
    testWidgets('Follow route button shows with a route and fires',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var followed = false;
      await tester.pumpWidget(_host(RideDetailDialog(
        rwt: RideWithTrackpoints(ride: _ride(), trackpoints: [
          Trackpoint(id: 1, rideId: 1, latitude: 48.0, longitude: 11.0, timestamp: 0),
          Trackpoint(id: 2, rideId: 1, latitude: 48.001, longitude: 11.0, timestamp: 1),
        ]),
        stats: const RideStats(
            durationMs: 1, distanceMetres: 1, maxSpeedKmh: 1, avgSpeedKmh: 1),
        onDismiss: () {},
        onFollowRoute: () => followed = true,
      )));
      final button = find.widgetWithText(FilledButton, 'Follow route');
      expect(button, findsOneWidget);
      await tester.tap(button);
      expect(followed, isTrue);
    });

    testWidgets('no Follow route button without a route or callback',
        (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(_host(RideDetailDialog(
        rwt: RideWithTrackpoints(ride: _ride(), trackpoints: const []),
        stats: const RideStats(
            durationMs: 1, distanceMetres: 1, maxSpeedKmh: 1, avgSpeedKmh: 1),
        onDismiss: () {},
        onFollowRoute: () {},
      )));
      expect(find.text('Follow route'), findsNothing);
    });
```

> Match the `Trackpoint` constructor to the generated Drift class (`lib/data/db/app_database.g.dart`) — copy how the existing detail-dialog tests in this file build trackpoints.

Also add a fullscreen check to the first test's end:
```dart
      await tester.tap(find.byIcon(Icons.fullscreen));
      await tester.pumpAndSettle();
      expect(find.text('Follow route'), findsNothing);
```

In `history_screen_test.dart`:
```dart
  testWidgets('3-dot menu Follow route opens the record question',
      (tester) async {
    await pump(tester, [_routedEntry(5)], trackpoints: {
      5: [_tp(5, 52.0, 13.0), _tp(5, 52.01, 13.0)],
    });
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    final items = tester
        .widgetList<PopupMenuItem<int>>(find.byType(PopupMenuItem<int>))
        .toList();
    expect(items.length, 3); // Follow route, Edit, Delete
    await tester.tap(find.text('Follow route'));
    await tester.pumpAndSettle();
    expect(find.text('Record this ride?'), findsOneWidget);
  });

  testWidgets('3-dot menu has no Follow route for a ride without a route',
      (tester) async {
    await pump(tester, [_entry(1, desc: 'Morning roll')]);
    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();
    expect(find.text('Follow route'), findsNothing);
  });
```

- [ ] **Step 2: Run to verify failure**

Run: `flutter test test/history/`
Expected: FAIL — `onFollowRoute` isn't a parameter / "Follow route" not found.

- [ ] **Step 3: Detail dialog** — add the field:

```dart
    this.onFollowRoute,
  ...
  /// Starts "Follow route" (Spec 17). Null hides the button.
  final VoidCallback? onFollowRoute;
```

Replace the bottom `Padding(... Align(... TextButton ...))` with:

```dart
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                child: Row(
                  children: [
                    if (widget.onFollowRoute != null && points.length >= 2)
                      FilledButton.tonalIcon(
                        onPressed: widget.onFollowRoute,
                        icon: const Icon(Icons.route),
                        label: Text(l10n.followRouteAction),
                      ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onDismiss,
                      child: Text(
                        l10n.actionClose,
                        style: text.labelLarge?.copyWith(color: colors.primary),
                      ),
                    ),
                  ],
                ),
              ),
```

(The fullscreen layout is a separate branch of `build` that doesn't include this row. Verify the fullscreen test from Step 1 passes as-is.)

- [ ] **Step 4: History card** — add `this.onFollowRoute,` + `final VoidCallback? onFollowRoute;` (doc: "Starts 'Follow route'; null hides the menu entry"). Pass it into the menu call: `_OverflowMenu(onEdit: ..., onDelete: ..., onFollowRoute: hasRoute ? widget.onFollowRoute : null)`. Rewrite `_OverflowMenu`:

```dart
class _OverflowMenu extends StatelessWidget {
  const _OverflowMenu(
      {required this.onEdit, required this.onDelete, this.onFollowRoute});
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onFollowRoute;

  static const _follow = 2, _edit = 0, _delete = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    return PopupMenuButton<int>(
      tooltip: l10n.a11yMoreOptions,
      icon: Icon(Icons.more_vert, size: 20, color: colors.onSurfaceVariant),
      onSelected: (v) => switch (v) {
        _follow => onFollowRoute?.call(),
        _edit => onEdit(),
        _ => onDelete(),
      },
      itemBuilder: (context) => [
        if (onFollowRoute != null)
          PopupMenuItem(
            value: _follow,
            child: Row(
              children: [
                Icon(Icons.route, color: colors.onSurface, size: 20),
                const SizedBox(width: 12),
                Text(l10n.followRouteAction),
              ],
            ),
          ),
        PopupMenuItem(
          value: _edit,
          child: Row(
            children: [
              Icon(Icons.edit, color: colors.onSurface, size: 20),
              const SizedBox(width: 12),
              Text(l10n.actionEdit),
            ],
          ),
        ),
        PopupMenuItem(
          value: _delete,
          child: Row(
            children: [
              Icon(Icons.delete, color: colors.deleteActionText, size: 20),
              const SizedBox(width: 12),
              Text(l10n.actionDelete,
                  style: TextStyle(color: colors.deleteActionText)),
            ],
          ),
        ),
      ],
    );
  }
}
```

- [ ] **Step 5: History screen wiring** — import `../follow/follow_route_launcher.dart`. Add to `_HistoryScreenState`:

```dart
  /// Loads [ride]'s route and starts "Follow route" for it (Spec 17).
  Future<void> _followRoute(Ride ride) async {
    final tps = await ref
        .read(trackpointRepositoryProvider)
        .getForRide(ride.rideId)
        .first;
    if (!mounted) return;
    await launchFollowRoute(
      context,
      ref,
      reference: [for (final tp in tps) (lat: tp.latitude, lng: tp.longitude)],
      rideTitle: ride.description,
    );
  }
```

In `_openDetail`'s `RideDetailDialog(...)` add:
```dart
        onFollowRoute: () {
          Navigator.of(context).pop();
          _followRoute(entry.ride);
        },
```
In the `HistoryRideCard(...)` construction add:
```dart
          onFollowRoute: () => _followRoute(item.ride),
```

- [ ] **Step 6: Run tests**

Run: `flutter test test/history/`
Expected: all PASS (existing ones unchanged).

- [ ] **Step 7: Commit**

```bash
git add lib/features/history test/history
git commit -m "feat(history): Follow route in the ride detail and the card menu"
```

---

### Task 7: `LiveMap` reference layers + heading trail (tests alongside)

**Files:**
- Modify: `lib/map/live_map.dart`
- Modify: `lib/features/active_ride/widgets/ride_chrome.dart` (`RideMapArea`)
- Test: `test/map/live_map_geojson_test.dart` (pure helper), `test/active_ride/active_ride_screen_test.dart` untouched

**Interfaces:**
- Consumes: `RouteTrack.splitAt` (Task 2).
- Produces:
  - `LiveMap({..., RouteTrack? reference, double? referenceProgressM, List<RoutePoint>? headingTrail})`
  - `RideMapArea({..., RouteTrack? reference, double? referenceProgressM, List<RoutePoint>? headingTrail})` — passed straight to `LiveMap`
  - pure `({String done, String ahead}) referenceGeoJson(RouteTrack track, double? progressM)` in `live_map.dart`
  - `const double kReferenceRouteOpacity = 0.45;`

- [ ] **Step 1: Write the failing pure test** (append to `live_map_geojson_test.dart`; add the imports `package:retrail/domain/route_progress.dart` and `dart:convert` if missing)

```dart
  group('referenceGeoJson', () {
    final track = RouteTrack(const [
      (lat: 48.0, lng: 11.0),
      (lat: 48.001, lng: 11.0),
      (lat: 48.002, lng: 11.0),
    ]);

    test('no progress yet: everything ahead, nothing done', () {
      final g = referenceGeoJson(track, null);
      expect((jsonDecode(g.done) as Map)['type'], 'FeatureCollection');
      final ahead = jsonDecode(g.ahead) as Map<String, dynamic>;
      expect((ahead['geometry']['coordinates'] as List).length, 3);
    });

    test('mid-route: done and ahead meet at the cut', () {
      final g = referenceGeoJson(track, track.lengthM / 4);
      final done = jsonDecode(g.done) as Map<String, dynamic>;
      final ahead = jsonDecode(g.ahead) as Map<String, dynamic>;
      expect((done['geometry']['coordinates'] as List).last,
          (ahead['geometry']['coordinates'] as List).first);
    });
  });
```

Run: `flutter test test/map/live_map_geojson_test.dart`
Expected: FAIL — `referenceGeoJson` / `RouteTrack` undefined in this library.

- [ ] **Step 2: Implement in `live_map.dart`**

Imports: `import '../domain/route_progress.dart' show RouteTrack;`

Helper + constant (near `routeLineGeoJson`):

```dart
/// Opacity of the reference route being followed (Spec 17): clearly behind
/// the live line, still readable on both basemaps.
const double kReferenceRouteOpacity = 0.45;

/// GeoJSON for the followed reference: the part already ridden ([done],
/// greyed) and the part ahead, cut at [progressM] (null = nothing ridden yet).
({String done, String ahead}) referenceGeoJson(
    RouteTrack track, double? progressM) {
  final split = track.splitAt(progressM ?? 0);
  return (done: routeLineGeoJson(split.done), ahead: routeLineGeoJson(split.ahead));
}
```

Constructor params + fields (docs on each):

```dart
    this.reference,
    this.referenceProgressM,
    this.headingTrail,
  ...
  /// A saved route being followed (Spec 17), drawn semi-transparent under the
  /// live line with its start/finish markers and arrows. Null = not following
  /// (no reference sources or layers are added at all).
  final RouteTrack? reference;

  /// How far along [reference] the rider is; the part behind is greyed.
  final double? referenceProgressM;

  /// Positions the heading-up camera turns by, instead of [points]. The
  /// follow-only screen passes its recent fixes here because it draws no
  /// line of its own.
  final List<RoutePoint>? headingTrail;
```

In `_onStyleLoaded`, **before** `await style.addSource(GeoJsonSource(id: 'route', ...))`:

```dart
    final reference = widget.reference;
    if (reference != null) {
      final g = referenceGeoJson(reference, widget.referenceProgressM);
      await style.addSource(GeoJsonSource(id: 'reference', data: g.ahead));
      await style.addSource(GeoJsonSource(id: 'reference-done', data: g.done));
      await style.addLayer(LineStyleLayer(
        id: 'reference-done-line',
        sourceId: 'reference-done',
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': _hex(colors.onSurfaceVariant),
          'line-width': 4.5,
          'line-opacity': kReferenceRouteOpacity,
        },
      ));
      await style.addLayer(LineStyleLayer(
        id: 'reference-halo',
        sourceId: 'reference',
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': halo,
          'line-width': 8.0,
          'line-opacity': kReferenceRouteOpacity,
        },
      ));
      await style.addLayer(LineStyleLayer(
        id: 'reference-line',
        sourceId: 'reference',
        layout: const {'line-cap': 'round', 'line-join': 'round'},
        paint: {
          'line-color': blue,
          'line-width': 4.5,
          'line-opacity': kReferenceRouteOpacity,
        },
      ));
    }
```

Right **after** the existing `route-arrows` layer is added (the arrow image is registered there — adding it twice throws):

```dart
    if (reference != null) {
      await style.addLayer(
        SymbolStyleLayer(
          id: 'reference-arrows',
          sourceId: 'reference',
          layout: {
            'symbol-placement': 'line',
            'symbol-spacing': _arrowSpacingPx,
            'icon-image': _arrowImage,
            'icon-size': _iconSize(_arrowIconSize, pixelRatio),
            'icon-rotation-alignment': 'map',
            'icon-keep-upright': false,
            'icon-allow-overlap': true,
            'icon-ignore-placement': true,
          },
          paint: const {'icon-opacity': kReferenceRouteOpacity},
        ),
        belowLayerId: 'route-halo',
      );
    }
```

In the `else` (live map) branch of the marker section, before the current marker is added (so it sits on top):

```dart
      if (reference != null) {
        final rp = reference.points;
        switch (routeEndpointStyle(rp)) {
          case RouteEndpointStyle.none:
            break;
          case RouteEndpointStyle.startOnly:
            await _addEndpointMarker(style, 'ref-start', rp.first,
                RouteMarkerImage.start, colors, pixelRatio);
          case RouteEndpointStyle.open:
            await _addEndpointMarker(style, 'ref-start', rp.first,
                RouteMarkerImage.start, colors, pixelRatio);
            await _addEndpointMarker(style, 'ref-end', rp.last,
                RouteMarkerImage.finish, colors, pixelRatio);
          case RouteEndpointStyle.loop:
            await _addEndpointMarker(style, 'ref-start', rp.first,
                RouteMarkerImage.loop, colors, pixelRatio);
        }
      }
```

Push method + call sites:

```dart
  /// Re-cuts the reference at the rider's progress (done vs ahead).
  void _pushReference() {
    final reference = widget.reference;
    if (reference == null) return;
    final g = referenceGeoJson(reference, widget.referenceProgressM);
    _style?.updateGeoJsonSource(id: 'reference', data: g.ahead);
    _style?.updateGeoJsonSource(id: 'reference-done', data: g.done);
  }
```

- In `didUpdateWidget`, after the `_pushRoute()` block:
```dart
    if (_sourcesReady &&
        widget.reference != null &&
        widget.referenceProgressM != oldWidget.referenceProgressM) {
      _pushReference();
    }
```
- In `_onStyleLoaded`, after the catch-up `_pushRoute();`: `_pushReference();`
- Replace the heading block in `didUpdateWidget`:
```dart
    final trail = widget.headingTrail ?? widget.points;
    final oldTrail = oldWidget.headingTrail ?? oldWidget.points;
    if (!widget.fitBounds && trail != oldTrail && trail.isNotEmpty) {
      _heading = nextHeading(_heading, trail.last);
    }
```
  (Identical behaviour when `headingTrail` is null.)

Placeholder: in `build`, before the `Stack`:
```dart
      final referenceFit = !widget.fitBounds && widget.reference != null
          ? fitRouteCamera(widget.reference!.points,
              width: size.width, height: size.height)
          : null;
```
and change the placeholder child to:
```dart
              child: fit != null
                  ? RouteSketch(points: widget.points, camera: fit)
                  : referenceFit != null
                      ? RouteSketch(
                          points: widget.reference!.points, camera: referenceFit)
                      : ColoredBox(color: colors.mapTerrain),
```

> A `null` reference changes nothing: no extra sources, layers, markers or pushes, and the placeholder stays `ColoredBox`.

- [ ] **Step 3: `RideMapArea` pass-through** (`ride_chrome.dart`)

Add the optional params `this.reference, this.referenceProgressM, this.headingTrail` with fields `final RouteTrack? reference; final double? referenceProgressM; final List<RoutePoint>? headingTrail;` (import `../../../domain/route_progress.dart`), and pass them to `LiveMap(...)`:
```dart
            reference: reference,
            referenceProgressM: referenceProgressM,
            headingTrail: headingTrail,
```

- [ ] **Step 4: Run tests**

Run: `flutter test test/map/ test/active_ride/ test/history/`
Expected: all PASS (existing map tests untouched).

- [ ] **Step 5: Commit**

```bash
git add lib/map/live_map.dart lib/features/active_ride/widgets/ride_chrome.dart test/map/live_map_geojson_test.dart
git commit -m "feat(map): draw a followed reference route under the live line"
```

---

### Task 8: Active ride with a reference (Red-Green-Refactor)

**Files:**
- Create: `lib/features/follow/widgets/follow_chrome.dart`
- Modify: `lib/features/active_ride/active_ride_screen.dart` (`build`, `_goHome`)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`
- Test: `test/active_ride/active_ride_follow_test.dart` (new file; the existing screen test stays untouched)

**Interfaces:**
- Consumes: `routeFollowProvider`, `RouteFollowState`, `RouteProgress`; `RideWarningBanner`, `RideMapArea` (Task 7).
- Produces:
  - `class FollowRemainingLine extends StatelessWidget { FollowRemainingLine({required RouteProgress? progress}) }`
  - `Widget? followBanner(BuildContext context, RouteProgress? progress)` — the "X km to the route" / "Off route" banner, or null.

- [ ] **Step 1: ARB keys**

`app_en.arb`:
```json
  "followRemaining": "{distance} to go",
  "@followRemaining": { "placeholders": { "distance": { "type": "String" } } },
  "followDistanceToRoute": "{distance} to the route",
  "@followDistanceToRoute": { "placeholders": { "distance": { "type": "String" } } },
  "followOffRouteBanner": "Off route — head back to the line",
  "followFinished": "Finish reached",
```
`app_de.arb`:
```json
  "followRemaining": "noch {distance}",
  "followDistanceToRoute": "{distance} bis zur Strecke",
  "followOffRouteBanner": "Abseits der Strecke — zurück zur Linie",
  "followFinished": "Ziel erreicht",
```
Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests.** Copy the harness from `test/active_ride/active_ride_screen_test.dart` (the fakes `_NoopSource`, `_NoopService`, `_GrantedPerms`, the fake controller/recording classes and `pumpScreen`) into the new file, then add `routeFollowProvider.overrideWith(() => _FixedFollow(follow))` to the overrides:

```dart
class _FixedFollow extends RouteFollowNotifier {
  _FixedFollow(this.initial);
  final RouteFollowState? initial;
  bool stopped = false;
  @override
  RouteFollowState? build() => initial;
  @override
  void stop() {
    stopped = true;
    state = null;
  }
}

RouteFollowState followState({RouteProgress? progress, bool recording = true}) =>
    RouteFollowState(
      track: RouteTrack(const [(lat: 48.0, lng: 11.0), (lat: 48.01, lng: 11.0)]),
      recording: recording,
      progress: progress,
    );

RouteProgress progress({
  double along = 300,
  double remaining = 812,
  double offset = 3,
  bool off = false,
  bool joined = true,
  bool finished = false,
}) =>
    RouteProgress(
        alongM: along,
        remainingM: remaining,
        offsetM: offset,
        isOffRoute: off,
        isFinished: finished,
        hasJoined: joined);
```

Tests:

```dart
  testWidgets('without a reference: no remaining line, no follow banner',
      (tester) async {
    await pumpScreen(tester, state: tracking, follow: null);
    expect(find.byType(FollowRemainingLine), findsNothing);
    final map = tester.widget<RideMapArea>(find.byType(RideMapArea));
    expect(map.reference, isNull);
  });

  testWidgets('recording with a reference: map gets it, remaining line shows',
      (tester) async {
    await pumpScreen(tester,
        state: tracking, follow: followState(progress: progress()));
    final map = tester.widget<RideMapArea>(find.byType(RideMapArea));
    expect(map.reference, isNotNull);
    expect(map.referenceProgressM, 300);
    expect(find.text('0.81 km to go'), findsOneWidget);
  });

  testWidgets('before joining: distance-to-route banner', (tester) async {
    await pumpScreen(tester,
        state: tracking,
        follow: followState(
            progress: progress(joined: false, off: true, offset: 250)));
    expect(find.text('0.25 km to the route'), findsOneWidget);
  });

  testWidgets('off route after joining: off-route banner', (tester) async {
    await pumpScreen(tester,
        state: tracking,
        follow: followState(progress: progress(off: true, offset: 45)));
    expect(find.text('Off route — head back to the line'), findsOneWidget);
  });

  testWidgets('a follow-only reference is not shown on the ride screen',
      (tester) async {
    await pumpScreen(tester,
        state: tracking,
        follow: followState(progress: progress(), recording: false));
    expect(find.byType(FollowRemainingLine), findsNothing);
  });

  testWidgets('leaving the ride clears the reference', (tester) async {
    final follow = await pumpScreen(tester,
        state: tracking, follow: followState(progress: progress()));
    // Back → discard confirm → Discard (same path as the existing discard test).
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(follow.stopped, isTrue);
  });
```

where `tracking` is `const RideTrackingState(isTracking: true)` and `pumpScreen` returns the `_FixedFollow` instance it installed (build it before `pumpWidget` and override with `routeFollowProvider.overrideWith(() => instance)`). Match the Back tooltip and the "Discard" label to the strings used by the existing discard test in `active_ride_screen_test.dart`.

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/active_ride/active_ride_follow_test.dart`
Expected: FAIL — `FollowRemainingLine` undefined.

- [ ] **Step 4: Implement `follow_chrome.dart`**

```dart
// lib/features/follow/widgets/follow_chrome.dart
import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../domain/formatters.dart';
import '../../../domain/route_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../active_ride/widgets/ride_chrome.dart';

/// "X km to go" strip above the ride panel while following (Spec 17).
class FollowRemainingLine extends StatelessWidget {
  const FollowRemainingLine({super.key, required this.progress});

  final RouteProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final p = progress;
    final label = p == null
        ? ''
        : p.isFinished
            ? l10n.followFinished
            : l10n.followRemaining(formatDistanceKm(p.remainingM, locale: locale));
    return Container(
      width: double.infinity,
      color: colors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(label,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: colors.onSurface)),
    );
  }
}

/// The follow banner: "X to the route" before the rider has joined, "Off
/// route" after leaving it, otherwise none.
Widget? followBanner(BuildContext context, RouteProgress? progress) {
  if (progress == null || !progress.isOffRoute) return null;
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  return RideWarningBanner(
    label: progress.hasJoined
        ? l10n.followOffRouteBanner
        : l10n.followDistanceToRoute(
            formatDistanceKm(progress.offsetM, locale: locale)),
  );
}
```

- [ ] **Step 5: Wire `ActiveRideScreen`**

In `build`, after `final l10n = ...`:
```dart
    // Spec 17: a reference only shows on a RECORDING follow; null = today.
    final follow = ref.watch(routeFollowProvider);
    final following = follow != null && follow.recording ? follow : null;
    final banner = following == null ? null : followBanner(context, following.progress);
```
After the location-off banner:
```dart
                  if (banner != null) banner,
```

`RideMapArea(...)` gets:
```dart
                      reference: following?.track,
                      referenceProgressM: following?.progress?.alongM,
```
Replace the stats `Expanded(flex: 35, child: RideStatsPanel(...))` child with:
```dart
                    child: following == null
                        ? panel
                        : Column(children: [
                            FollowRemainingLine(progress: following.progress),
                            Expanded(child: panel),
                          ]),
```
where `panel` is the unchanged `RideStatsPanel(...)` expression hoisted into a local `final panel = RideStatsPanel(...);` just above the `return PopScope(`.

In `_goHome`, before `context.go(AppRoutes.main);`:
```dart
    // Spec 17: the reference ends with the ride (save, skip, discard, gate).
    ref.read(routeFollowProvider.notifier).stop();
```
Imports: `../follow/route_follow_providers.dart`, `../follow/widgets/follow_chrome.dart`.

- [ ] **Step 6: Run tests**

Run: `flutter test test/active_ride/`
Expected: all PASS — the existing `active_ride_screen_test.dart` unchanged and green.

- [ ] **Step 7: Commit**

```bash
git add lib/features/follow/widgets lib/features/active_ride lib/l10n test/active_ride/active_ride_follow_test.dart
git commit -m "feat(ride): show the followed route, remaining distance and off-route banner"
```

---

### Task 9: Follow-only screen (Red-Green-Refactor)

**Files:**
- Modify: `lib/features/follow/follow_route_screen.dart` (replace the stub)
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_de.arb`
- Test: `test/follow/follow_route_screen_test.dart`

**Interfaces:**
- Consumes: `routeFollowProvider` (`resumeFeed`, `pauseFeed`, `stop`), `RideMapArea`, `RideWarningBanner`, `rideChromeBg`/`rideChromeAccent`, `FollowRemainingLine`, `followBanner`, `navigateTo` + `navigationLauncherProvider` (`lib/features/home/navigation_chooser.dart`, `navigation_launcher.dart`), `rideRecordingControllerProvider.openLocationSettings`.
- Produces: the full `FollowRouteScreen`.

- [ ] **Step 1: ARB keys**

`app_en.arb`:
```json
  "followRouteTitle": "Follow route",
  "followNavigateToStart": "Navigate to start",
  "followEndAction": "End",
  "followEndConfirmTitle": "End following?",
  "followEndConfirmBody": "Your position won't be shown on the route anymore.",
```
`app_de.arb`:
```json
  "followRouteTitle": "Strecke nachfahren",
  "followNavigateToStart": "Zum Start navigieren",
  "followEndAction": "Beenden",
  "followEndConfirmTitle": "Folgen beenden?",
  "followEndConfirmBody": "Deine Position wird dann nicht mehr auf der Strecke angezeigt.",
```
Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

```dart
// test/follow/follow_route_screen_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:retrail/core/connectivity/connectivity_providers.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/domain/route_progress.dart';
import 'package:retrail/features/follow/follow_route_screen.dart';
import 'package:retrail/features/follow/route_follow_providers.dart';
import 'package:retrail/features/home/navigation_launcher.dart';
import 'package:retrail/l10n/app_localizations.dart';

import '../support/live_map_stub.dart';

class FakeNavigationLauncher implements NavigationLauncher {
  final launches = <(double, double, String)>[];
  @override
  Future<List<NavigationApp>> availableApps() async =>
      const [NavigationApp.system];
  @override
  Future<void> launch(
          NavigationApp app, double lat, double lng, String label) async =>
      launches.add((lat, lng, label));
}

class _FakeFollow extends RouteFollowNotifier {
  _FakeFollow(this.initial);
  final RouteFollowState? initial;
  final calls = <String>[];
  @override
  RouteFollowState? build() => initial;
  @override
  Future<void> resumeFeed() async => calls.add('resume');
  @override
  void pauseFeed() => calls.add('pause');
  @override
  void stop() {
    calls.add('stop');
    state = null;
  }
}

RouteFollowState _state({String? title = 'Rhein', RouteProgress? progress}) =>
    RouteFollowState(
      track: RouteTrack(const [(lat: 48.0, lng: 11.0), (lat: 48.01, lng: 11.0)]),
      recording: false,
      rideTitle: title,
      progress: progress,
    );

RouteProgress _p({bool joined = true, bool off = false, double offset = 2,
        double remaining = 812, bool finished = false}) =>
    RouteProgress(alongM: 300, remainingM: remaining, offsetM: offset,
        isOffRoute: off, isFinished: finished, hasJoined: joined);

void main() {
  useStubLiveMap();
  late _FakeFollow follow;
  late FakeNavigationLauncher launcher;

  Future<void> pump(WidgetTester tester, RouteFollowState? s) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    follow = _FakeFollow(s);
    launcher = FakeNavigationLauncher();
    final router = GoRouter(initialLocation: '/follow', routes: [
      GoRoute(path: '/', builder: (c, s) => const Text('HOME')),
      GoRoute(path: '/follow', builder: (c, s) => const FollowRouteScreen()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        routeFollowProvider.overrideWith(() => follow),
        isOnlineProvider.overrideWith((ref) => Stream.value(true)),
        navigationLauncherProvider.overrideWithValue(launcher),
      ],
      child: MaterialApp.router(
        theme: buildTheme(Brightness.light),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ));
    await tester.pump();
  }

  testWidgets('title, ride title and remaining distance', (tester) async {
    await pump(tester, _state(progress: _p()));
    expect(find.text('Follow route'), findsOneWidget);
    expect(find.text('Rhein'), findsOneWidget);
    expect(find.text('0.81 km to go'), findsOneWidget);
    expect(follow.calls, contains('resume'));
  });

  testWidgets('no ride title line when the ride has none', (tester) async {
    await pump(tester, _state(title: null, progress: _p()));
    expect(find.text('Rhein'), findsNothing);
  });

  testWidgets('End asks first; Cancel keeps following', (tester) async {
    await pump(tester, _state(progress: _p()));
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    expect(find.text('End following?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(follow.calls, isNot(contains('stop')));
    expect(find.text('HOME'), findsNothing);
  });

  testWidgets('End confirmed stops and goes home', (tester) async {
    await pump(tester, _state(progress: _p()));
    await tester.tap(find.text('End'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'End').last);
    await tester.pumpAndSettle();
    expect(follow.calls, contains('stop'));
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('system back opens the same confirmation', (tester) async {
    await pump(tester, _state(progress: _p()));
    final dynamic widgetsAppState = tester.state(find.byType(WidgetsApp));
    await widgetsAppState.didPopRoute();
    await tester.pumpAndSettle();
    expect(find.text('End following?'), findsOneWidget);
  });

  testWidgets('not on the route yet: banner + Navigate to start',
      (tester) async {
    await pump(tester, _state(progress: _p(joined: false, off: true, offset: 250)));
    expect(find.text('0.25 km to the route'), findsOneWidget);
    await tester.tap(find.text('Navigate to start'));
    await tester.pump();
    expect(launcher.launches.first.$1, 48.0);
  });

  testWidgets('on the route: no Navigate to start', (tester) async {
    await pump(tester, _state(progress: _p()));
    expect(find.text('Navigate to start'), findsNothing);
  });

  testWidgets('finish reached hint', (tester) async {
    await pump(tester, _state(progress: _p(finished: true, remaining: 3)));
    expect(find.text('Finish reached'), findsOneWidget);
  });

  testWidgets('app backgrounded pauses the feed, foreground resumes it',
      (tester) async {
    await pump(tester, _state(progress: _p()));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(follow.calls.last, 'pause');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(follow.calls.last, 'resume');
  });

  testWidgets('without a reference it goes home', (tester) async {
    await pump(tester, null);
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);
  });
}
```

> The launcher fake mirrors the one in `history_screen_test.dart` (that one is file-private, so it's repeated here).

- [ ] **Step 3: Run to verify failure**

Run: `flutter test test/follow/follow_route_screen_test.dart`
Expected: FAIL — stub screen renders nothing ("Follow route" not found).

- [ ] **Step 4: Implement the screen**

```dart
// lib/features/follow/follow_route_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/theme/theme_context.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/ride_tracking_state.dart';
import '../../tracking/tracking_providers.dart';
import '../active_ride/widgets/ride_chrome.dart';
import '../home/navigation_chooser.dart';
import '../home/navigation_launcher.dart';
import '../shell/routes.dart';
import 'route_follow_providers.dart';
import 'widgets/follow_chrome.dart';

/// Follow-only mode (Spec 17 §E2): the saved route with the rider's live
/// position, remaining distance and off-route banner — nothing is recorded.
/// GPS runs only while the app is in the foreground.
class FollowRouteScreen extends ConsumerStatefulWidget {
  const FollowRouteScreen({super.key});

  @override
  ConsumerState<FollowRouteScreen> createState() => _FollowRouteScreenState();
}

class _FollowRouteScreenState extends ConsumerState<FollowRouteScreen>
    with WidgetsBindingObserver {
  late final RouteFollowNotifier _follow;
  bool _isFollowing = true;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _follow = ref.read(routeFollowProvider.notifier);
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(routeFollowProvider) == null) {
        _leave();
      } else {
        _follow.resumeFeed();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _follow.pauseFeed();
    if (state == AppLifecycleState.resumed) _follow.resumeFeed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    _follow.stop();
    context.go(AppRoutes.main);
  }

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context);
    final end = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.followEndConfirmTitle),
        content: Text(l10n.followEndConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.actionCancel)),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.followEndAction)),
        ],
      ),
    );
    if (end == true && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final follow = ref.watch(routeFollowProvider);
    final isOnline = ref.watch(isOnlineProvider).asData?.value ?? true;
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (follow == null) return Scaffold(backgroundColor: rideChromeBg.surface);
    final progress = follow.progress;
    final banner = followBanner(context, progress);
    final notJoined = progress == null || !progress.hasJoined;
    final title = follow.rideTitle?.trim();
    final start = follow.track.points.first;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: rideChromeBg.surface,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: rideChromeBg.surface,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _confirmEnd,
                      icon: const Icon(Icons.arrow_back),
                      color: rideChromeAccent.hintText,
                      tooltip: l10n.a11yBack,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.followRouteTitle,
                              style: text.titleMedium
                                  ?.copyWith(color: rideChromeAccent.surface)),
                          if (title != null && title.isNotEmpty)
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall
                                    ?.copyWith(color: rideChromeAccent.hintText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOnline) RideWarningBanner(label: l10n.mapOfflineBanner),
              if (!follow.locationServiceEnabled)
                RideWarningBanner(
                  label: l10n.rideLocationOffBanner,
                  onTap: ref.read(rideRecordingControllerProvider).openLocationSettings,
                ),
              if (banner != null) banner,
              Expanded(
                child: RideMapArea(
                  state: RideTrackingState(location: follow.lastFix),
                  isFollowing: _isFollowing,
                  masked: _leaving,
                  reference: follow.track,
                  referenceProgressM: progress?.alongM,
                  headingTrail: follow.trail,
                  onGesture: () {
                    if (_isFollowing) setState(() => _isFollowing = false);
                  },
                  onRecenter: () => setState(() => _isFollowing = true),
                ),
              ),
              FollowRemainingLine(progress: progress),
              Container(
                color: colors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    if (notJoined)
                      FilledButton.tonalIcon(
                        onPressed: () => navigateTo(
                            context,
                            ref.read(navigationLauncherProvider),
                            start.lat,
                            start.lng,
                            title ?? l10n.followRouteTitle),
                        icon: const Icon(Icons.directions),
                        label: Text(l10n.followNavigateToStart),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: _confirmEnd,
                      child: Text(l10n.followEndAction),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

> The "End" button is a `FilledButton` and the dialog's confirm is a `TextButton`, so the test's `find.widgetWithText(TextButton, 'End')` hits the dialog only. `/follow` is only left through `_leave` (back is intercepted by `PopScope`; the ride deep link can't fire because follow-only can't start while a ride records), so `dispose` doesn't touch the provider — modifying a provider during widget disposal is unsafe in Riverpod.

- [ ] **Step 5: Run tests**

Run: `flutter test test/follow/`
Expected: all PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/follow lib/l10n test/follow
git commit -m "feat(follow): follow-only screen with end confirmation and navigate-to-start"
```

---

### Task 10: Docs, full verification, integrate

**Files:**
- Modify: `CLAUDE.md` (architecture tree: `features/` list gets `follow/`; conventions line on `routeFollowProvider`)
- Modify: `lib/map/CLAUDE.md` (live map: optional reference layers, `headingTrail`, placeholder sketch)
- Modify: `docs/specs/17-follow-route.md` (status → IMPLEMENTED, pending on-device; §A: card entry shown when the ride has a route, the launcher ignores < 2 points; §C: follow-only gate reuses `RideRecordingController.prepare()`; the reference is cleared by `_leave` / Home start / ride exit, not on widget disposal; §E1: the "X km to go" line sits above the stats panel)

- [ ] **Step 1: Update the docs**

`CLAUDE.md` architecture block: `│   ├── onboarding/  home/  timer/  active_ride/  history/  settings/  profile/  follow/`. Under **Conventions** add:
```markdown
- `routeFollowProvider` (Spec 17) holds a followed reference route, process-lifetime like `RideTracker` but separate from it: recording follows read the recorder's position, follow-only (`/follow`) runs its own foreground GPS feed. Null = no reference; every screen then behaves as without the feature.
```
`lib/map/CLAUDE.md`, append to the live-map bullet:
```markdown
  Optional **reference route** (Spec 17, `reference` + `referenceProgressM`): `reference` / `reference-done` sources drawn below the live line at `kReferenceRouteOpacity`, ridden part in `onSurfaceVariant`, its own start/finish markers (`ref-start`/`ref-end`) and arrows; the pre-style placeholder then sketches the reference. `headingTrail` lets the follow-only screen drive heading-up without drawing a line. Null reference → no extra sources or layers.
```

- [ ] **Step 2: Full verification**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests pass. If anything fails, fix it before continuing (superpowers:verification-before-completion).

- [ ] **Step 3: Commit docs**

```bash
git add CLAUDE.md lib/map/CLAUDE.md docs/specs/17-follow-route.md
git commit -m "docs: spec 17 follow route — architecture and map guide"
```

- [ ] **Step 4: Integrate (local only; ask before any push)**

```bash
git fetch -q 2>/dev/null; git rebase main
flutter analyze && flutter test
git checkout main && git merge --ff-only phase/17-follow-route
git branch -d phase/17-follow-route
```

- [ ] **Step 5: On-device acceptance (with the user)**

Android + iOS (iOS via `tool/ios_fetch_build.sh` after a push the user approves):
- Follow-only and recording, each from the detail dialog and from the card menu.
- Joining mid-route; a loop route; leaving the route (> 30 m) and back; standing still (progress holds).
- Far from the start: banner + "Navigate to start" opens the external app.
- App backgrounded in follow-only → GPS icon off; back → position resumes.
- Offline (airplane mode): reference still drawn (sketch placeholder without a cached style).
- After a followed ride: a normal Home ride shows no reference.
Record results in the spec's status line.
