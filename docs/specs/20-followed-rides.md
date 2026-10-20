# Spec 20: Followed rides

**Status:** IMPLEMENTED — on-device check pending. Approved in conversation on 2026-10-20.
**Depends on:** Spec 17 (follow a saved route, `routeFollowProvider`), Spec 18 (direction, ridden intervals), Spec 13 (History list, filter, detail dialog).

## Goal
A ride recorded while following a saved ride is **linked** to that original instead of standing alone in History. Linked rides can be compared (distance, duration, speed, best time) and filtered. Overwriting the original was considered and dropped: it would destroy the original's record.

## Behaviour
1. **When a ride is linked.** Only a *recorded* follow of a *saved ride* links, and only once the rider actually **joined** the route (`progress.hasJoined`). A recording that never reached the route stays a plain ride. Follow-only (`/follow`) records nothing, so nothing links. The link is written **when the recording stops** — whichever way it ends (summary Save or Skip, or Stop from the notification / Live Activity); a discarded ride is deleted anyway.
2. **What is stored.** `rides.followed_ride_id` (nullable, `ON DELETE SET NULL`), `rides.follow_coverage` (0–1, the share of the reference ridden, `followCoverage` over the follow's ridden intervals) — schema v4 — and `rides.follow_route_ms` (time on the route, v5, see 7).
3. **Flat groups.** Choosing "Follow route" on a ride that is itself a follow follows *its original* — that route, title and link (`HistoryController.followSource`) — so the coverage is measured against the whole route, and a route group is always "original + every ride with that `followed_ride_id`".
4. **Deleting the original** keeps its follows; the database clears their link, their chips go and they are plain rides again. A route filter choice whose original is gone is dropped (`HistoryFilterNotifier.keepRoutes`).
5. **Saving.** The post-ride summary suggests the original's title (editable).
6. **History card chips** (tappable, `Icons.alt_route`, primary-container colours): a follow shows **"Followed"** (de: „Nachgefahren“), an original **"n× followed"** (de: „n× nachgefahren“). Either opens the **comparison sheet** of the group, the tapped ride selected. In selection mode the chips do nothing.
7. **Comparison sheet** (`RouteGroupSheet`): header = original's title and distance; sections **Original**, **Followed (n)** (complete follows, oldest first) and **Partial — no best time** (de: „Teilstrecken – ohne Bestzeit“, only when there are any). Each row: date/time, then `km · duration · Ø km/h`. A follow is **complete** at `follow_coverage ≥ 0.9` (`fullCoverageThreshold`); a missing coverage counts as partial. The **best time** (trophy) is the shortest positive duration among the original and the complete follows, shown only when at least two compete; ties keep the older ride. A follow competes with its **time on the route** (`rides.follow_route_ms`, schema v5, #79): the recording time, pauses excluded, from joining the route to the last fix that grew the ridden part — the way to the route and anything past the finish don't count. The original competes with its whole duration (its ride *is* the route). Each row shows the time it competes with. Tapping a row opens that ride's detail. A section without rides is left out.
8. **Ride detail**: a follow shows **"Followed from “title” · dd.MM.yyyy ›"** (untitled: the full date title), which opens the original's detail; an original shows **"n× followed ›"**, which opens the comparison sheet.
9. **Filter "Followed routes"** (de: „Nachgefahrene Strecken“), shown only when at least one route was followed. The row reads "All routes", up to two route names, or "n routes". It opens a picker sheet (not a dropdown: a search field and multi-select inside a popup in the filter sheet fight the keyboard and nested scrolling) with a search field, then one row per followed original — route preview, title, "n rides · last date", checkbox — most recently ridden first. The choice applies on **Apply**; **Reset** unchecks all. History then shows the chosen originals and their follows, combined with every other filter.

## Code
- Data: `tables.dart`, `app_database.dart` (v4), `RideDao.updateFollowedRide / watchFollowCounts / watchRouteGroup / watchFollowedRoutes`, `followed_route.dart` (`FollowedRoute`, `RouteRoot`).
- Domain: `follow_coverage.dart`, `route_group.dart`, `route_selection.dart`, `formatRideDay`.
- Follow: `RouteFollowState.sourceRideId / coverage / followLink`; `RouteFollowNotifier` writes the link through `followLinkWriterProvider` when the recorder stops.
- Save: `PostRideSummaryDialog.initialTitle`.
- History: `route_group_providers.dart`, `widgets/route_group_sheet.dart`, `widgets/route_picker_sheet.dart`, `widgets/route_link_row.dart`, `widgets/ride_preview_thumbnail.dart`.

## Non-goals
Overwriting or replacing the original; grouping rides that were *not* recorded as follows (e.g. by matching geometry); time comparisons per segment.
