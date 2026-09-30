# Spec 18: Follow a route in either direction

**Status:** DRAFT. Approved in conversation on 2026-09-30.
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

## Model
- `RouteFollowState.track` stays the **original** route. It is the session identity that `pauseFeedFor` relies on (#50).
- New fields:
  - `direction` (`FollowDirection.undecided | forward | reverse`)
  - `orientedTrack` (the original track, or its reversed copy; the reversed copy is built once at `start`)
  - `ridden` (`List<LatLng>`, the greyed segment in map order; empty while undecided)
- `progress` is progress on `orientedTrack`. While undecided it is forward progress.

## Map (`LiveMap`)
- `referenceProgressM` is replaced by `referenceDone` (`List<RoutePoint>?`).
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
