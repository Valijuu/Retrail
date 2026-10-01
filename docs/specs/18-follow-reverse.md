# Spec 18: Follow a route in either direction

**Status:** IMPLEMENTED — on-device check pending (#49). Approved in conversation on 2026-09-30.
**Depends on:** Spec 17 (follow a saved route: `RouteTrack`/`RouteProgress`, `routeFollowProvider`, reference layers in `LiveMap`, ride screen and follow screen).

## Goal
A rider can follow a saved route **backwards**. Today, starting at the route's finish marks the whole route as ridden at once: the line is greyed out, "0 km to go" shows, and "Finish reached" appears. With this spec the direction is detected automatically. Arrows, start/finish markers, "X km to go" and "Finish reached" then follow the rider's actual direction, and a rider who turns around mid-route can flip the direction by hand.

This removes "riding a route in reverse" from Spec 17's non-goals.

## Behaviour
1. **Direction at the join.** This is the first fix that is on the route.
   - Within `followFinishRadiusM` (30 m) of the route's **first** point → **forward**, decided immediately.
   - Within 30 m of the **last** point → **reverse**, decided immediately.
   - A **loop** (first and last point within 30 m of each other), or a join anywhere else → **undecided**.
   - A start or finish zone the route also passes mid-route (a pass of the route through the join more than 30 m from both ends, e.g. a "6" whose finish lies on its own middle) → **undecided**, decided by movement (#54). The zones are by straight distance, the mid-route test by distance along, so a join 30 m from the start past a tight first bend is undecided as well.
2. **Undecided → decided by movement.**
   - The join is placed on the closest pass of the route through the first on-route fix. Passes that fit about as well (within 4 m, or within 15 m on a pass running the other way: the same road ridden back) also count; of these the first along the route is the join. On a loop the route is laid out twice, and a join within 60 m of the start moves to the second lap so its window reaches back across the start/finish.
   - Each fix is projected onto the route, **without** monotonic hold, within one window from 60 m (`followJoinWindowM`) before the first of the join's passes to 60 m after the last. On a route whose passes through the join lie far apart along it (a road ridden back much later) this window also takes in the route between them; a pass crossed there counts towards the nearest of the join's passes, and because its displacement is capped by the straight distance from the join point (below) it can only decide once the rider is at least 35 m from the join. Its **signed displacement** is how far along the route it lies from the join on its pass (`along − joinAlong`), at most the straight-line distance from the join point: a fix near a corner also lies near the other leg, far along the route.
   - **Forward** once a displacement reaches **+35 m** (`followDirectionDecisionM`), **reverse** once one reaches **−35 m**. Where the route runs both ways along one road (an out-and-back, a lollipop's stem) the rider is ahead on one pass and behind on the other: forward is the default. Only passes the rider has fitted about as well as the best since the join (average distance within 4 m) count.
   - While the rider stays within 8 m of the join, the join settles on the average of their positions, so GPS scatter around a rider standing at the join does not decide.
   - When a fix is off route or outside the window, the join is placed again from that fix.
   - On deciding, the ridden range is `[join, current]` on the deciding pass, and the lap of a loop runs from the join on that pass.
3. **Decided = fixed.** The direction is never re-detected automatically. A U-turn on an out-and-back route can't be told apart from riding the return leg.
4. **Manual flip.**
   - A map button **"Reverse direction"** is shown while following once the rider has joined the route. The icon is `Icons.swap_vert`, placed bottom-right; it is a round, app-surface control like recenter.
   - It flips the direction at once. Progress continues from the rider's current position on the flipped route.
   - While undecided, it forces the opposite of the provisional forward direction, i.e. reverse, from the join.
   - Once decided, a flip is either a **correction** or a **U-turn** (#55), measured on the new orientation. When the rider is found on the flipped route as far ahead of the mirrored join as they have ridden (the travel since the join runs forward in the new orientation, e.g. a lollipop joined at its start/finish, defaulted to forward and flipped at the top of the stem), it is a correction: the join stays the anchor, so "to go" counts to the true end and "Finish reached" appears there; the ridden range is re-measured from the join. Otherwise it is a U-turn: on a loop a fresh lap starts where the rider is, and the ridden range is kept. The rider is looked for from halfway to that point on (not from the mirrored join itself), so a rider who has just turned, still near the join, is never taken for a correction, and the hit there may be at most 15 m farther off the route than the rider currently is.
5. **Display while undecided.** The route shows **unchanged**, exactly like the ride detail: original arrows, no greyed part. "X km to go" shows the route's total length.
6. **Ridden part.**
   - Only what the rider actually rode since joining is greyed: a segment from the join point to the furthest point reached, kept in the original route's coordinates as a `[lo, hi]` range. The part the rider skipped stays normal.
   - It is shown from the moment the direction is decided. A manual flip keeps it (a correction re-measures it from the join on the new orientation).
   - The range only grows while the rider is on the route.
7. **Oriented display once decided.**
   - The reference line, arrows and start/finish markers are drawn on the **oriented** route. For reverse, that is the reversed point list.
   - "X km to go", the finish hint and the off-route / distance-to-route banners use progress on the oriented route.
   - When reversed, the remaining line reads **"{distance} to go · opposite direction"** (de: **"noch {distance} · Gegenrichtung"**).
   - When the direction turns to reverse on its own (not by the manual flip), a snack bar tells the rider why, once: joined at the finish → "You're starting at the route's finish, so it's followed in the opposite direction." (de: "Du startest am Ziel der Strecke, sie wird in Gegenrichtung nachgefahren."); decided by movement → "Opposite direction detected: the route is followed the other way." (de: "Gegenrichtung erkannt: Die Strecke wird andersherum nachgefahren."). `RouteFollowState.reverseNotice` carries the cause; `listenFollowReverseNotice` shows it on both screens.
8. Both modes (recording and follow-only) behave the same. What is recorded is unaffected: it is always the rider's actual track.

## Loops (circular progress)
A route is a **loop** when its first and last points are within `followFinishRadiusM` (30 m) of each other. This is the same test `directionAtJoin` uses. Loops were broken before this section: a rider who joined mid-loop saw "Finish reached" as soon as they came near the start/finish point, progress stuck there, and then almost the whole loop greyed.

1. **Seamless crossing.** For a loop, progress is tracked on the route laid out twice (two laps back to back), in each orientation. Crossing the start/finish point simply continues along the second lap: no jump and no stall.
2. **One lap from the join.** For a loop:
   - "X km to go" is the distance left to complete **one full lap from where the rider joined**: `joinAlong + L − along`, never negative and at most one lap. The join is the rider's position on the pass that decided the direction (a join at the seam counts from the nearest point, not from the start), or after a U-turn flip the turn.
   - "Finish reached" means the rider has ridden at least `followFinishMinShare` (90 %) of the loop's length since joining **and** is within `followFinishRadiusM` of the join point.
3. **Ridden parts may wrap.** The ridden range is kept on the doubled route. It is drawn as **up to two segments** on the single-lap route (a range that crosses the seam splits in two), or as the whole loop once a full lap is ridden. This closes the wrap-around case of issue #51; the shortcut case is closed by the pass jumps below.
4. Open routes (not loops) behave exactly as described above; nothing changes for them.

## Implementation
- The logic is the pure `lib/domain/follow_tracker.dart` (`FollowTracker`, no Flutter imports); `lib/domain/follow_direction.dart` holds the helpers (`directionAtJoin`, `decideDirection`, ...). `routeFollowProvider` only feeds it fixes and exposes its state.
- **Undecided window.** `lib/domain/follow_join.dart` (`FollowJoin`) holds the join, one anchor per pass of the road through it, each pass's fit and the settling; `decideDirection` takes the signed displacements.
- **Decided progress** (`lib/domain/follow_progress.dart`, `decidedProgress`): of the fix's hits from 30 m behind progress to 30 m beyond how far the rider is from the progress point, the one that best fits the rider wins (close to the route, about as far along from the progress point as the rider is from it, not more than 5 m behind progress, on a pass running the way the rider heads over the last fixes). Progress never goes back and advances per fix by at most the rider's recent pace + 2 m, then a quarter of the rest, so a noisy fix across a corner, a hairpin or an out-and-back's turnaround is caught up with over a few fixes instead of moving progress onto a later pass of the same road. Off route, Spec 17's look-ahead and full search.
- **Pass jumps.** A progress change with `|Δalong| > moved + 60 m` is a jump to another pass of the route. It is a **shortcut** when it is also more than 60 m beyond the straight-line distance from the rider's last fix on the route (the rider cut across, on or off route). A shortcut re-bases the join value and does **not** extend the ridden range: the range so far is kept as a ridden part of its own and a new one starts at the jump, so the skipped stretch stays ungreyed (#51). A part is shown once it has length. Any other jump (the rider rode off route alongside the route and rejoined farther on) extends the range like a step. A rider who was more than 60 m off the route since their last fix on it took **another way**: rejoining, jump or not, also starts a new part, so a stretch skipped for a different road stays ungreyed even where it runs straight.
- **Doubled laps on loops.** A finished lap is **latched** until a flip. A U-turn flip on a loop starts a fresh lap and shifts the kept range by the lap offset; a correction keeps the join (`lib/domain/follow_flip.dart`).
- `RouteFollowState.displayProgress` returns null while the direction is undecided, so the remaining text shows the route's total length.
- **Scenario suite.** `test/domain/follow_tracker_scenarios_test.dart` is the yardstick for every change to the tracker. It runs seeded simulated rides over six route shapes, with these rider behaviours: start, finish, mid-route, across the seam, standing still, slow/fast, an off-route excursion and a flip. Each ride runs under five GPS noise models. A ride checks:
  - the final direction (on a same-road out-and-back, either direction counts);
  - "to go" within 40 m of the true distance left, once decided and not finished;
  - no "finished" before the real finish;
  - the finish reached;
  - ridden parts within 40 m of the ridden road.

  Thresholds come in tiers:
  - **Gate** (200 runs): no failing run without noise, ≤ 2 % for uniform ±5 m and a correlated random walk, ≤ 5 % for Gaussian σ5.
  - **Stress** (Gaussian σ8, 100 runs): ≤ 15 %, and no more than the committed baseline (`test/domain/support/follow_scenarios_baseline.dart`) + 3 runs. The long-term target is 5 %.

  A local-only group replays the user's real rides (a gitignored fixture, never committed) with the same checks, and each ride along its own geometry under the gate noise models (50 runs each, gate thresholds). Pairs still over their threshold are skipped by default and tracked in #56.

## UI layout
- On the ride screen the banners and the follow line sit in the **map area**, so the stats panel keeps a constant height with any banner (checked at iPhone 8 size).
- The follow-only screen has a merged bottom bar: progress on the left, End on the right, and a full-width "Navigate to start" before the rider joins.

## Known limitations
- #52: a join near an out-and-back turnaround greys the unridden tip.
- #53: approximations on gap loops and after a pass jump.
- A lollipop joined exactly at its start/finish and ridden the reverse way goes up the stem first, which is the same road both ways. At the top of the stem the direction may be forward (the default), reverse, or still undecided. If it is not reverse, the rider fixes it with the manual flip, which is a correction: the lap still runs from the join.
- #56: scenario pairs still over their threshold (correlated walk on the 100 m square and at turnarounds, a slow rider at an out-and-back's turnaround under σ8, a real gap loop whose start is the same road both ways).

## Model
- `RouteFollowState.track` stays the **original** route. It is the session identity that `pauseFeedFor` relies on (#50).
- New fields:
  - `direction` (`FollowDirection.undecided | forward | reverse`)
  - `orientedTrack` (the original track, or its reversed copy; the reversed copy is built once at `start`)
  - `ridden` (`List<List<LatLng>>`, the greyed segments in map order: one per ridden part (a pass jump starts a new one), a part on a loop that crosses the seam split in two; empty while undecided)
- `progress` is progress on `orientedTrack`. While undecided it is forward progress.

## Map (`LiveMap`)
- `referenceProgressM` is replaced by `referenceDone` (`List<List<RoutePoint>>?`), drawn as a MultiLineString.
- The `reference` source holds the **whole** oriented route. `reference-done` holds the ridden segment, drawn **above** the reference line but still below the live route.
- A replaced `reference` (a flip) re-pushes the line and also moves the start/finish marker points. This goes through the existing `_drawnReference` / `referencePushTarget` gate. The whole line is pushed only when the reference changes (`referenceUpdateGeoJson`, `_lastPushedReference`); a new ridden part pushes only `reference-done`.
- `RouteTrack.splitAt` is then unused and is removed.

## Non-goals
- Automatic re-detection after the direction is decided (see 3).
- Remembering a preferred direction per ride.
- The ghost rider (still "Later" in Spec 17).

## Testing
- **Domain (EXACT):**
  - `RouteTrack.reversed`
  - `RouteTrack.segmentBetween`
  - `directionAtJoin`, `decideDirection` (signed displacements)
  - `RouteTrack.hitsWithin`, `passesOf`, `progressAt`
  - `RiddenRange`
- **Provider (Red-Green-Refactor):**
  - join at the finish → reverse with nothing greyed and the full remaining length
  - join mid-route and move 40 m back → reverse; 40 m forward → forward
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
