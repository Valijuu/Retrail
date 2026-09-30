# Spec 18: Follow a route in either direction

**Status:** IMPLEMENTED on branch feature/follow-reverse — on-device check pending (#49). Approved in conversation on 2026-09-30.
**Depends on:** Spec 17 (follow a saved route: `RouteTrack`/`RouteProgress`, `routeFollowProvider`, reference layers in `LiveMap`, ride screen and follow screen).

## Goal
A rider can follow a saved route **backwards**. Today, starting at the route's finish marks the whole route as ridden at once: the line is greyed out, "0 km to go" shows, and "Finish reached" appears. With this spec the direction is detected automatically. Arrows, start/finish markers, "X km to go" and "Finish reached" then follow the rider's actual direction, and a rider who turns around mid-route can flip the direction by hand.

This removes "riding a route in reverse" from Spec 17's non-goals.

## Behaviour
1. **Direction at the join.** This is the first fix that is on the route.
   - Within `followFinishRadiusM` (30 m) of the route's **first** point → **forward**, decided immediately.
   - Within 30 m of the **last** point → **reverse**, decided immediately.
   - A **loop** (first and last point within 30 m of each other), or a join anywhere else → **undecided**.
2. **Undecided → decided by movement.**
   - Progress is tracked on the forward and the reversed route in parallel, each with Spec 17's monotonic `locate`.
   - Whichever one advances **25 m** (`followDirectionDecisionM`) past its join value first wins.
   - Riding against the original arrows advances only the reversed route, because forward progress holds. So the direction is reverse.
   - This reuses Spec 17's leg logic, so an out-and-back on the same road is not misread.
3. **Decided = fixed.** The direction is never re-detected automatically. A U-turn on an out-and-back route can't be told apart from riding the return leg.
4. **Manual flip.**
   - A map button **"Reverse direction"** is shown while following once the rider has joined the route. The icon is `Icons.swap_vert`, placed bottom-right; it is a round, app-surface control like recenter.
   - It flips the direction at once. Progress continues from the rider's current position on the flipped route.
   - While undecided, it forces the opposite of the provisional forward direction, i.e. reverse.
5. **Display while undecided.** The route shows **unchanged**, exactly like the ride detail: original arrows, no greyed part. "X km to go" shows the route's total length.
6. **Ridden part.**
   - Only what the rider actually rode since joining is greyed: a segment from the join point to the furthest point reached, kept in the original route's coordinates as a `[lo, hi]` range. The part the rider skipped stays normal.
   - It is shown from the moment the direction is decided. A manual flip keeps it.
   - The range only grows while the rider is on the route.
7. **Oriented display once decided.**
   - The reference line, arrows and start/finish markers are drawn on the **oriented** route. For reverse, that is the reversed point list.
   - "X km to go", the finish hint and the off-route / distance-to-route banners use progress on the oriented route.
   - When reversed, the remaining line reads **"{distance} to go · reversed"** (de: **"noch {distance} · rückwärts"**).
8. Both modes (recording and follow-only) behave the same. What is recorded is unaffected: it is always the rider's actual track.

## Loops (circular progress)
A route is a **loop** when its first and last points are within `followFinishRadiusM` (30 m) of each other. This is the same test `directionAtJoin` uses. Loops were broken before this section: a rider who joined mid-loop saw "Finish reached" as soon as they came near the start/finish point, progress stuck there, and then almost the whole loop greyed.

1. **Seamless crossing.** For a loop, progress is tracked on the route laid out twice (two laps back to back), in each orientation. Crossing the start/finish point simply continues along the second lap: no jump and no stall.
2. **One lap from the join.** For a loop:
   - "X km to go" is the distance left to complete **one full lap from where the rider joined**: `joinAlong + L − along`, never negative.
   - "Finish reached" means the rider has ridden at least `followFinishMinShare` (90 %) of the loop's length since joining **and** is within `followFinishRadiusM` of the join point.
3. **Ridden parts may wrap.** The ridden range is kept on the doubled route. It is drawn as **up to two segments** on the single-lap route (a range that crosses the seam splits in two), or as the whole loop once a full lap is ridden. This closes the wrap-around case of issue #51 (the shortcut case stays open).
4. Open routes (not loops) behave exactly as described above; nothing changes for them.

## Implementation
- The logic is the pure `lib/domain/follow_tracker.dart` (`FollowTracker`, no Flutter imports); `lib/domain/follow_direction.dart` holds the helpers (`directionAtJoin`, `decideDirection`, ...). `routeFollowProvider` only feeds it fixes and exposes its state.
- **Reverse tracker join.** The reverse tracker joins at the mirrored forward join (the same physical point seen from the other end), so both trackers start on the same spot.
- **Pass jumps.** A progress change with `|Δalong| > moved + 60 m` is a jump to another pass of the route (a shortcut, or a loop wrap). It re-bases that tracker's join value and does **not** extend the ridden range.
- **One ridden range per tracker** until the direction is decided. Deciding keeps the winner's range; a flip converts the range to the new orientation.
- **Doubled laps on loops.** A finished lap is **latched** until a flip. A flip on a loop starts a fresh lap and shifts the kept range by the lap offset.
- `RouteFollowState.displayProgress` returns null while the direction is undecided, so the remaining text shows the route's total length.

## UI layout
- On the ride screen the banners and the follow line sit in the **map area**, so the stats panel keeps a constant height with any banner (checked at iPhone 8 size).
- The follow-only screen has a merged bottom bar: progress on the left, End on the right, and a full-width "Navigate to start" before the rider joins.

## Known limitations
- #51: the ridden overlay is one interval; loop wrap-around is handled here, but the skipped part after an accepted shortcut stays a limitation.
- #52: a join near an out-and-back turnaround greys the unridden tip.
- #53: approximations on gap loops and after a pass jump.

## Model
- `RouteFollowState.track` stays the **original** route. It is the session identity that `pauseFeedFor` relies on (#50).
- New fields:
  - `direction` (`FollowDirection.undecided | forward | reverse`)
  - `orientedTrack` (the original track, or its reversed copy; the reversed copy is built once at `start`)
  - `ridden` (`List<List<LatLng>>`, the greyed segments in map order: one for open routes, up to two for a loop whose ridden part crosses the seam; empty while undecided)
- `progress` is progress on `orientedTrack`. While undecided it is forward progress.

## Map (`LiveMap`)
- `referenceProgressM` is replaced by `referenceDone` (`List<List<RoutePoint>>?`), drawn as a MultiLineString.
- The `reference` source holds the **whole** oriented route. `reference-done` holds the ridden segment, drawn **above** the reference line but still below the live route.
- A replaced `reference` (a flip) re-pushes the line and also moves the start/finish marker points. This goes through the existing `_drawnReference` / `referencePushTarget` gate.
- `RouteTrack.splitAt` is then unused and is removed.

## Non-goals
- Automatic re-detection after the direction is decided (see 3).
- Remembering a preferred direction per ride.
- The ghost rider (still "Later" in Spec 17).

## Testing
- **Domain (EXACT):**
  - `RouteTrack.reversed`
  - `RouteTrack.segmentBetween`
  - `directionAtJoin`, `decideDirection`
  - `RiddenRange`
- **Provider (Red-Green-Refactor):**
  - join at the finish → reverse with nothing greyed and the full remaining length
  - join mid-route and move 25 m back → reverse; 25 m forward → forward
  - loop at the start → decided by movement
  - out-and-back return leg → not misread
  - flip → progress continues and the ridden part is kept
  - undecided → no ridden segment
  - `pauseFeedFor` still works after a flip
- **Widgets:**
  - the remaining line's reversed suffix and total-while-undecided
  - the flip button shown only after joining and calling the notifier
  - both screens wired
- **Map:** pure helpers for the GeoJSON and the marker points. The rendering itself is checked on a device (issue #49).
