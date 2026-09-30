# Follow in Either Direction — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a rider follow a saved route backwards. The direction is detected automatically, the rider can flip it by hand, and only the part actually ridden is greyed.

**Architecture:**
- New pure domain helpers (EXACT): `RouteTrack.reversed()`, `RouteTrack.segmentBetween()`, and `lib/domain/follow_direction.dart` with `FollowDirection`, `directionAtJoin`, `decideDirection` and `RiddenRange`.
- `RouteFollowNotifier` tracks forward and reversed progress while undecided, then keeps one oriented progress plus a ridden range in original coordinates. `track` stays the original route (session identity).
- `LiveMap` swaps `referenceProgressM` for `referenceDone` and moves the reference markers on a flip.
- The UI gains a flip button and a "· reversed" suffix.

**Tech Stack:** Flutter (Material 3), flutter_riverpod 3 (hand-written), maplibre 0.3.6, ARB l10n (en + de), flutter_test.

**Spec:** `docs/specs/18-follow-reverse.md` (binding), on top of `docs/specs/17-follow-route.md`.

## Global Constraints
- **Hard invariant:** without a reference, every screen behaves exactly as today, and `RideTracker` and the recording pipeline stay untouched. A forward follow that starts at the route start looks and behaves as in Spec 17, except that only the ridden part is greyed.
- `RouteFollowState.track` stays the ORIGINAL route for the whole session. `pauseFeedFor(track)` compares against it.
- **Constants:**
  - `followFinishRadiusM` (30 m) is the start and finish zone for the join decision; reuse it.
  - New `followDirectionDecisionM = 25`.
  - Loop = the first and last point within `followFinishRadiusM`.
- Direction is never re-detected automatically after it is decided. It changes only through the manual flip.
- **Display while undecided:** the route is unchanged (original orientation), there is no ridden segment, and the remaining line shows the total length.
- **Ridden part:** keep `[lo, hi]` in original-route metres. Grow it only from on-route fixes. Show it only once decided. A flip keeps it.
- **Copy:**
  - "Reverse direction" / "Richtung umkehren" (tooltip)
  - "{distance} to go · reversed" / "noch {distance} · rückwärts"
- **Code rules:**
  - Every string goes in BOTH ARBs, hand-edited in the existing style, then run `flutter gen-l10n`.
  - `AppColors` tokens only. No path header comments.
  - Don't run `dart format` on pre-existing files.
  - No interactive git.
- **Commit trailer**, every commit ends with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01EsGoTVrF7J45ATGuogtCrm
  ```
- **Methodology:**
  - Domain (`lib/domain/`): EXACT via `Skill({skill: "tdd-dart"})` in autonomous mode.
  - Provider and widgets: Red-Green-Refactor.
  - Native map layers: tests alongside the change.
- **Done =** `flutter analyze` prints "No issues found!" and the full `flutter test` passes.

## Review Focus
1. Out-and-back on the same road, join mid-outbound, riding forward: must decide **forward** and never flip to reverse at the turnaround.
2. Loop joined at its start: forward and reversed both find a join near along 0. The decision must come only from 25 m of movement, never at the join.
3. A flip while off route, or before the join: the button is hidden before the join. While off route, flip keeps progress unjoined-safe (no crash, no NaN).
4. `pauseFeedFor` after a flip must still pause the session's feed, because `track` is unchanged.
5. Brightness rebuild after a flip: the map redraws the oriented route and markers from the current props, with no stale original orientation.

---

### Task 1: Domain — `RouteTrack.reversed` and `segmentBetween` (EXACT)

**Files:** Modify `lib/domain/route_progress.dart`. Test in `test/domain/route_progress_test.dart`, new groups.

**Produces:**
- `RouteTrack RouteTrack.reversed()`: a new track over `points.reversed`, same `DistanceCalculator`.
- `List<LatLng> RouteTrack.segmentBetween(double fromM, double toM)`: the polyline from `fromM` to `toM` along the route.
  - Both values are clamped to `[0, lengthM]`, and swapped if `fromM > toM`.
  - Interior cut points are interpolated.
  - A cut within `_vertexSnapM` of a vertex lands on that vertex, so there is no near-duplicate point.
  - Returns `[]` when `toM - fromM <= _vertexSnapM` or the route has no length.

**Test list** (reuse the file's `at(n, e)` helper and `_straight` = 0/100/200/300 m north):
1. `reversed` of `_straight`: points are 300/200/100/0, `lengthM` ≈ 300, `cumulativeM` = [0, 100, 200, 300] (±0.5).
2. `reversed` of a single-point route: 1 point, `lengthM` 0.
3. `segmentBetween(0, 300)`: all 4 points.
4. `segmentBetween(150, 250)`: [at(150), at(200), at(250)].
5. `segmentBetween(250, 150)` (swapped): same as 4.
6. `segmentBetween(100, 200)`: exactly [at(100), at(200)], no duplicates.
7. `segmentBetween(120, 120)`: [].
8. `segmentBetween(-50, 50)`: [at(0), at(50)] (clamped).
9. `segmentBetween` on a route of length 0: [].

- [ ] EXACT cycle over the list, then the refactor agent.
- [ ] `flutter test test/domain/route_progress_test.dart` green, `flutter analyze lib/domain` clean.
- [ ] Commit `feat(domain): reverse a route and cut a segment out of it (spec 18)`.

### Task 2: Domain — `follow_direction.dart` (EXACT)

**Files:** Create `lib/domain/follow_direction.dart`. Test in `test/domain/follow_direction_test.dart`.

**Produces:**
```dart
enum FollowDirection { undecided, forward, reverse }

/// Distance a rider must move along the route before the direction is decided.
const double followDirectionDecisionM = 25;

/// Direction decided at the join: forward in the start zone, reverse in the
/// finish zone, undecided elsewhere and always on a loop.
FollowDirection directionAtJoin(RouteTrack track, LatLng position,
    {DistanceCalculator distance = const HaversineDistanceCalculator()});

/// Forward/reverse once either advance reaches [followDirectionDecisionM]
/// (forward wins a tie), else undecided.
FollowDirection decideDirection(
    {required double forwardAdvanceM, required double reverseAdvanceM});

/// The ridden stretch of the original route, in original-route metres.
class RiddenRange {
  const RiddenRange(this.loM, this.hiM);
  const RiddenRange.at(double m) : loM = m, hiM = m;
  final double loM, hiM;
  RiddenRange extend(double m); // min/max
}
```
Zones use `followFinishRadiusM`. Loop = distance(first, last) ≤ `followFinishRadiusM`. The zone test measures the distance from `position` to `points.first` / `points.last`. A route with < 2 points or no length is undecided.

**Test list:**
- `directionAtJoin`:
  - at the start → forward
  - 29 m from the start → forward
  - at the finish → reverse
  - mid-route → undecided
  - 31 m from the start → undecided
  - loop (finish 5 m from start), at the start → undecided
  - single-point route → undecided
- `decideDirection`:
  - (0, 0) → undecided
  - (24.9, 0) → undecided
  - (25, 0) → forward
  - (0, 25) → reverse
  - (30, 30) → forward (tie rule)
- `RiddenRange`:
  - `.at(100)` → lo = hi = 100
  - `.extend(150)` → 100–150
  - then `.extend(80)` → 80–150
  - `.extend(120)` inside → unchanged

- [ ] EXACT cycle and refactor.
- [ ] Green and analyze-clean.
- [ ] Commit `feat(domain): decide the follow direction and track the ridden range (spec 18)`.

### Task 3: Provider — direction, ridden segment, flip (Red-Green-Refactor)

**Files:** Modify `lib/features/follow/route_follow_providers.dart`. Test in `test/follow/route_follow_providers_test.dart`.

**Consumes:** Tasks 1–2.

**Produces:**

`RouteFollowState` gains:
- `final FollowDirection direction`, default `undecided`
- `final RouteTrack orientedTrack`
- `final List<LatLng> ridden`, default `const []`
- `bool get isReversed => direction == FollowDirection.reverse`

`start()` builds the original `track`, sets `orientedTrack = track`, and keeps the reversed copy privately in the notifier (`_reversedTrack`), built once.

`copyWith` carries `direction`, `orientedTrack` and `ridden`.

`RouteFollowNotifier` gains `void flipDirection()`.

**Algorithm** (all in `onFix` after the accuracy gate; `p` is the fix):
- **Undecided:**
  - `fwd = track.locate(p, previous: _fwdPrev)` and `rev = _reversedTrack.locate(p, previous: _revPrev)`.
  - Store both as the new previous values.
  - On the first fix where `fwd.hasJoined` becomes true:
    - remember `_fwdJoin = fwd.alongM` and `_revJoin = rev.alongM`
    - set `_ridden = RiddenRange.at(fwd.alongM)`
    - `d = directionAtJoin(track, p)`; if decided, apply it (below)
  - Afterwards, while undecided:
    - if `fwd` is on route, extend `_ridden` with `fwd.alongM`, and if `rev` is on route, extend it with `track.lengthM - rev.alongM`
    - `d = decideDirection(forwardAdvanceM: fwd.alongM - _fwdJoin, reverseAdvanceM: rev.alongM - _revJoin)`; if decided, apply it
  - State while undecided:
    - `progress = fwd`
    - `ridden = const []`
    - `orientedTrack = track`
- **Apply direction `d`:**
  - `orientedTrack = d == reverse ? _reversedTrack : track`
  - `progress = d == reverse ? rev : fwd`
  - Drop the other tracker.
- **Decided:**
  - `progress = orientedTrack.locate(p, previous: progress)`
  - If it is on route, convert to original metres (`isReversed ? track.lengthM - along : along`) and extend `_ridden`.
  - `ridden = track.segmentBetween(_ridden.loM, _ridden.hiM)`, reversed into map order when `isReversed`. The order doesn't matter visually; keep it simple.
  - Recompute `ridden` only when the range changed, so the list identity stays stable between fixes.
- **`flipDirection()`:**
  - Allowed only when `progress?.hasJoined == true`. Otherwise it is a no-op.
  - New direction = the opposite of the effective direction (undecided counts as forward).
  - The new oriented progress is `newTrack.locate(lastPoint, previous: RouteProgress(alongM: L − oldAlong, remainingM: oldAlong, offsetM: old.offsetM, isOffRoute: false, isFinished: false, hasJoined: true))`, where `L` is the track length and `lastPoint` is the last fix position.
  - Keep `_ridden`, and recompute `ridden` for the new orientation.
- `start()` / `stop()` reset all trackers.

**Tests** (reuse the file's fakes; use metre helper points like the domain tests, route 0 → 300 m north):
- join at 1 m from the finish → `direction == reverse`, `progress.alongM` ≈ 1, `remainingM` ≈ 299, `ridden` empty or tiny, `orientedTrack` identical to the reversed copy (first point = original last)
- join at 1 m from the start → forward
- join mid-route (150 m), then 160 m → forward after the 25 m advance at 175 (fixes 150, 165, 180 → forward decided at 180)
- join mid-route (150 m), then 140, 130, 120 → reverse (decided when the reversed advance reaches ≥ 25 at 125 or 120)
- undecided → `ridden` empty and `orientedTrack` identical to `track`
- after deciding forward at 180 and riding to 250 → `ridden` spans 150 to 250 (first point ≈ at(150), last ≈ at(250))
- out-and-back `[at(0,0), at(200,0), at(0,3)]`, joined at (50,0) and riding 60, 80, 100 → forward
- loop `[at(0,0), at(100,0), at(100,100), at(0,100), at(0,5)]`, first fix at (0,1) → undecided; then moving along the first leg to (30, 0) → forward
- `flipDirection` after forward at 200 m → `direction == reverse`, `progress.alongM` ≈ 100, `ridden` unchanged range
- `flipDirection` before join → no-op
- `pauseFeedFor(track)` after a flip pauses the feed (`track` unchanged)
- all existing provider tests still pass

- [ ] RED (see each fail), then GREEN, then refactor.
- [ ] `flutter test test/follow/` green, analyze clean.
- [ ] Commit `feat(follow): detect the riding direction and track the ridden part (spec 18)`.

### Task 3b: Loops — circular progress (EXACT for the tracker; RGR for the provider)

**Files:** Modify `lib/domain/follow_tracker.dart` (and add `RouteTrack` helpers in `lib/domain/route_progress.dart` if needed) and `lib/features/follow/route_follow_providers.dart`. Tests go in `test/domain/follow_tracker_test.dart` and `test/follow/route_follow_providers_test.dart`.

**Spec:** Spec 18, section "Loops (circular progress)". It is binding.

**Design (ruling):**
- **Loop detection.** A route is a loop when the distance from its first to its last point is at most `followFinishRadiusM`. Expose `bool get isLoop` on `FollowTracker` or `RouteTrack`.
- **Doubled tracks.** For a loop, the tracker's internal forward and reverse tracks are the route laid out twice. Build the doubled polyline as `points + points.skip(1)`. If the seam gap is not zero, the closing leg is simply part of the lap. Joins land in lap 1, because first-fix `passes.first` picks the lowest along. All existing machinery keeps working on the doubled tracks: mirrored join, jump re-base, per-tracker ranges, decision and flip. The mirror uses the doubled length.
- **`orientedTrack`** stays the SINGLE-lap oriented route, because it is used for drawing.
- **Loop progress mapping** (the `RouteProgress` exposed to consumers):
  - `alongM` = the doubled along.
  - `remainingM` = `max(0, joinAlong + L − along)`, where L is one lap and `joinAlong` is the oriented tracker's join along.
  - `isFinished` = `(along − joinAlong) ≥ followFinishMinShare × L` && the distance to the join position is ≤ `followFinishRadiusM`.
  - `offsetM`, `isOffRoute` and `hasJoined` are passed through.
- **Ridden segments.** Replace the single-range getter for consumers with `List<(double from, double to)> riddenIntervals`, given in single-lap metres of the ORIGINAL route.
  - Open route: at most one interval, as today.
  - Loop: map the range `[lo, hi]` from the doubled original metres. If `hi − lo ≥ L`, return one interval `[0, L]`. Otherwise reduce `lo` mod L and split at L, which gives one or two intervals.
- **Provider.** `ridden` becomes `List<List<LatLng>>`: `track.segmentBetween` for each interval, reversed into map order when `isReversed`. It is recomputed only when the intervals change, so its identity stays stable. Screens and the map switch to this type in Tasks 4 and 5. Adjust the current screens minimally so everything still compiles: flattening for the old single-list `referenceDone` is fine until Task 4, or change the map param type early.
- **Open routes** must behave exactly as after Task 3. All existing tracker and provider tests stay green.

**Test list** (square loop of L = 400 m: `at(0,0), at(100,0), at(100,100), at(0,100), at(0,0)`):
- `isLoop` is true for it, false for `_straight`, and true for a loop with a 20 m gap.
- Join at 340 (east 60 on the last leg), ride west through (0,0), then north to (0,60) at 10 m per fix:
  - `isFinished` is never true;
  - progress never stalls, i.e. `alongM` strictly increases each fix after the decision;
  - `remainingM` goes from ≈ 400 down to ≈ 280 at north 60;
  - the ridden intervals are two, ≈ [340, 400] and [0, 60].
- A full lap from the join at 340 back to 340 → finished, and the intervals are a single [0, 400].
- Loop joined at the start and ridden forward 30 m: the intervals are [0, 30], and it is not finished (the existing C1 case).
- The reverse loop cases from Task 3 (M3 and the at(2,2) repro) are still reverse, their intervals are within the ridden stretch, and nothing is finished early.
- Flip on a loop mid-lap: the direction flips, the intervals are kept, and it is not finished.
- Open routes: all existing expectations are unchanged.

- [ ] EXACT for the tracker, one test at a time, each RED first. Refactor inline.
- [ ] Provider RGR for the `ridden` list-of-segments mapping.
- [ ] `flutter analyze` is clean and the full `flutter test` suite is green.
- [ ] Commit `feat(follow): circular progress on loops (spec 18)`.

### Task 4: Map — oriented reference, ridden overlay, marker move, flip button

**Files:** Modify `lib/map/live_map.dart`, `lib/features/active_ride/widgets/ride_chrome.dart` (`RideMapArea`), `lib/domain/route_progress.dart` (remove `splitAt` and its tests), `lib/map/CLAUDE.md`. Tests in `test/map/live_map_geojson_test.dart` and `test/active_ride/` (a `RideMapArea` flip-button test).

**Produces:**
- `LiveMap({..., RouteTrack? reference, List<List<RoutePoint>>? referenceDone, ...})` (the ridden segments, drawn as a MultiLineString). `referenceProgressM` is removed.
- `({String done, String ahead}) referenceGeoJson(RouteTrack track, List<List<RoutePoint>>? done)`: `done` becomes a MultiLineString of the segments with ≥ 2 points:
  - `ahead` = the whole track line
  - `done` = `routeLineGeoJson(done ?? const [])`
- Pure `({RoutePoint start, RoutePoint? end}) referenceMarkerPoints(RouteEndpointStyle style, List<RoutePoint> points)`:
  - `start` = first point
  - `end` = last point for `open`, else null
- `RideMapArea({..., RouteTrack? reference, List<List<RoutePoint>>? referenceDone, VoidCallback? onReverse, ...})`.

**Changes:**
- Layer order at style load:
  - `reference-halo` and `reference-line` first
  - then `reference-done-line` (on top of the reference, `onSurfaceVariant`, `kReferenceRouteOpacity`)
  - all below the live `route` layers, as today
- Arrows stay on `reference`.
- `didUpdateWidget`:
  - push on `!identical(reference)` or `!identical(referenceDone)` (gated as today on `_sourcesReady` and `referencePushTarget`)
  - on a replaced reference, also `updateGeoJsonSource` the `ref-start` / `ref-end` point sources, only those this style load created: remember the endpoint style drawn at load, e.g. `_drawnReferenceMarkers`
- Remove `RouteTrack.splitAt`, the `RouteSplit` typedef and their tests. `referenceGeoJson` no longer uses them. Confirm with grep that nothing else does.
- `RideMapArea`: when `onReverse != null` and not masked, show a round `FloatingActionButton.small` bottom-right:
  - `kMapControlInset` from the right and bottom
  - app surface background with a primary icon, like recenter
  - `Icons.swap_vert`
  - tooltip `followReverseDirection`

  Add the ARB key `followReverseDirection` ("Reverse direction" / "Richtung umkehren").

**Tests:**
- `referenceGeoJson(track, null)` → done is an empty FeatureCollection, ahead has all points
- `referenceGeoJson(track, [a, b])` → done has 2 coordinates
- `referenceMarkerPoints`:
  - `open` → start/end are first/last
  - `loop` → end null
  - `startOnly` → end null
- `RideMapArea`:
  - `onReverse` set → the button with the tooltip is shown, and tapping it calls the callback
  - null → no button
  - masked → no button
- The existing map tests are updated for the `referenceProgressM` → `referenceDone` rename.

- [ ] Implement and test, keeping the existing `_sourcesReady` / `_superseded` gating (see lib/map/CLAUDE.md).
- [ ] Green and analyze-clean.
- [ ] Commit `feat(map): draw the oriented reference with its ridden part and move its markers on a flip (spec 18)`.

### Task 5: Screens — wire direction, flip, reversed suffix

**Files:** Modify `lib/features/follow/widgets/follow_chrome.dart` (`FollowRemainingLine`), `lib/features/active_ride/active_ride_screen.dart`, `lib/features/follow/follow_route_screen.dart`, and both ARBs. Tests in `test/active_ride/active_ride_follow_test.dart` and `test/follow/follow_route_screen_test.dart`.

**Produces:**
- `FollowRemainingLine({required RouteProgress? progress, required double totalM, bool reversed = false})`.
  - Reversed and not finished → `followRemainingReversed(distance)`.
  - ARB: `"followRemainingReversed": "{distance} to go · reversed"` with the placeholder, and de `"noch {distance} · rückwärts"`.

**Wiring** (both screens):
- the map gets `reference: following.orientedTrack` and `referenceDone: following.ridden`
- `FollowRemainingLine(progress: following.direction == FollowDirection.undecided ? null : following.progress, totalM: following.track.lengthM, reversed: following.isReversed)`
- `onReverse: following.progress?.hasJoined == true ? notifier.flipDirection : null`
- the banner keeps using `following.progress`
- the ride screen's exit freeze (`_followingAtExit`) and the follow screen's `_frozen` keep working, because they freeze the whole state

**Tests:**
- reversed state → "0.81 km to go · reversed"
- undecided state with progress → "X km to go" showing the total length
- joined → the flip button is shown, and tapping it calls `flipDirection` (fake notifier records the call)
- not joined → no flip button
- the map receives `orientedTrack` and `ridden`
- all on both screens

**User-reported additions (2026-09-30), part of this task:**
- **Ride screen, iPhone 8 bug.** The "X km to go" line currently sits inside the 35-flex stats area, where it steals height from `RideStatsPanel`. On short screens (iPhone 8, 375×667) the panel's rows are squeezed unevenly; on tall Android screens it looks fine. Move the line to the bottom of the **map's** 65-flex area: `Column[Expanded(RideMapArea), FollowRemainingLine]` when following. The stats panel must then get exactly the same height as without a reference.
  - Regression test at `Size(375, 667)`: `tester.getSize(find.byType(RideStatsPanel))` is identical with and without a recording follow.
  - Also check there is no overflow (`takeException` is null).
- **Follow-only screen bottom bar.** Once the rider is on the route, "End" stands alone at the bottom right, and "X km to go" sits in a separate strip above it. Merge them into ONE bar:
  - Row 1: the progress text on the left ("X km to go", "Finish reached", or "X km to go · reversed", styled prominently), and "End" (FilledButton) on the right.
  - Row 2, only before joining: a full-width `FilledButton.tonalIcon` "Navigate to start".
  - Remove the separate `FollowRemainingLine` strip on this screen. It may reuse the same text logic, e.g. a shared `followProgressLabel(...)` helper extracted from `FollowRemainingLine`.
  - Keep the existing tests' intent: End still confirms, navigate-to-start is still shown only before joining, and the label fallback is unchanged.
  - Check at 375 px in English and German that nothing truncates or overflows.

- [ ] Red-Green-Refactor, green, analyze-clean.
- [ ] Commit `feat(follow): flip button and reversed hint on both follow screens (spec 18)`.

### Task 6: Docs and verification
- Spec 17: in Non-goals, replace "Riding a route in reverse …" with "Reverse riding: see Spec 18".
- Spec 18: status → "IMPLEMENTED on branch feature/follow-reverse — on-device check pending (#49)".
- `CLAUDE.md` conventions bullet on `routeFollowProvider`: add the direction and the ridden part in one clause.
- `lib/map/CLAUDE.md`: the reference paragraph now describes the oriented route, the done overlay and the marker move on a flip.
- Run the full `flutter analyze` and `flutter test`.
- Commit `docs: spec 18 follow in either direction`.
