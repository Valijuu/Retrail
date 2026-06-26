# Spec 13 — Ride history

**Status:** DONE — implemented test-first; 247 total tests green, analyze clean
**Phase:** 13 of 15
**Depends on:** Spec 3 (`RideRepository.getAllRidesWithTrackpoints`, delete/update/favorite), Spec 4 (`computeRideStats`, `rideDisplayTitle`, `formatRideDayKey`/`formatDateLabel`/`formatRideTime`/`formatDuration`/`formatRideDate`, week/year bounds), Spec 7 + 12 (`RoutePreview` + `routePreviewCacheProvider`; `LiveMap` for the detail map), Spec 9 (`ActivityTypeUi`), Spec 10 (`navigationLauncherProvider`; `historyTargetRideProvider` + history tab in `MainShell`)
**Branch:** `phase/13-history`

---

## Goal

Port the original **`RideHistoryPage` + `RideHistoryViewModel` + `RideHistoryListItem` +
`RideDetailDialog`** in full. Replace the history placeholder tab (`MainShell` tab 1) with a real
`HistoryScreen`: a filtered/sorted/date-grouped list of ride cards (each with a **cached preview
PNG** thumbnail — the Spec 12 pipeline, so scrolling never fetches tiles), search, a filter bottom
sheet, multi-select + batch delete, a per-row 3-dot edit/delete menu, favorite toggle, a
navigate-to-start button, a ride-detail dialog (with fullscreen map), and an edit dialog. Honor the
**jump-to-ride** deep-link from Home (`historyTargetRideProvider`): scroll to the ride and highlight
it briefly.

Everything is fully `analyze` + `test` green — no device-gated pieces. (The detail/fullscreen map
uses `flutter_map`, whose on-device feel is tuned in Spec 7/Part B, but it builds and renders here.)

---

## Architecture

```
MainShell tab 1 ──► HistoryScreen (ConsumerStatefulWidget)
   │ watches historyItemsProvider, historyFilterProvider, activeFilterCountProvider,
   │          historyTargetRideProvider
   ▼
HistoryController (filter setters + ride mutations) ──► RideRepository (Spec 3)
historyItemsProvider = StreamProvider: getAllRidesWithTrackpoints() × filter
   → buildHistoryItems(...) pure pipeline (filter → stats → sort → group)
Cards embed RoutePreview(routePreviewCacheProvider)  (Spec 12 — cached PNGs)
```

### Domain — pure pipeline (`lib/features/history/history_items.dart`, test-first)

The filter/sort/group logic is **pure Dart** (mirrors `RideHistoryViewModel.ridesWithStats`),
extracted so it's unit-tested without widgets or Riverpod:

```dart
enum TimePeriod { thisWeek, thisMonth, thisYear, all }
enum SortOrder { date, distance, speed, duration }

class HistoryFilter {            // immutable; equatable
  TimePeriod period;             // default all
  SortOrder sort;                // default date
  String query;                  // default ''
  bool favoritesOnly;            // default false
  ActivityType? activity;        // default null (All)
}

sealed class HistoryItem {}
class DateHeaderItem extends HistoryItem { final String label; }      // localized Today/Yesterday/…
class RideEntryItem  extends HistoryItem { final RideWithTrackpoints rwt; final RideStats stats; }

/// rides + filter (+ now/locale + a DistanceCalculator) → display list.
List<HistoryItem> buildHistoryItems(
  List<RideWithTrackpoints> rides, HistoryFilter f, { required int nowMs, ... });

int activeFilterCount(HistoryFilter f);   // period≠all + sort≠date + favOnly + activity≠null (query excluded)
bool isFilterActive(HistoryFilter f);     // any of the above OR query non-empty
```

Pipeline, matched to the original:
1. **Filter**: favoritesOnly → `ride.isFavorite`; activity → `ride.typ == activity.id`; period →
   `(date ?? startTime ?? 0) >= periodStart`; query (trimmed, case-insensitive) → matches
   `rideDisplayTitle(ride)` **or** `ride.comment`.
2. **Stats**: `computeRideStats(rwt, calc)` per surviving ride (distance/maxSpeed/duration/avg).
3. **Sort/group**:
   - `date` → group by `formatRideDayKey(ride.date)`, **day keys descending**, insert a
     `DateHeaderItem(formatDateLabel(dayKey))`, rides within a day **date-descending**.
   - `distance` → flat, `stats.distanceMetres` desc.
   - `speed` → flat, `stats.maxSpeedKmh` desc.
   - `duration` → flat, `stats.durationMs` **asc** (shortest first — matches `sort_duration` = "Shortest duration").
4. **Period start** (epoch ms, local): reuse the existing week-start (Monday 00:00) and year-start
   helpers; **add `startOfMonth`** (1st 00:00) test-first. `all` → 0.

### Providers (`lib/features/history/history_providers.dart`)

- **`historyFilterProvider`** — `NotifierProvider<HistoryFilterNotifier, HistoryFilter>` with
  `setPeriod/setSort/setQuery/setFavoritesOnly/setActivity/reset`. (StateNotifier-style; the screen
  reads/writes it.)
- **`historyItemsProvider`** — `StreamProvider<List<HistoryItem>>` combining
  `rideRepository.getAllRidesWithTrackpoints()` with `historyFilterProvider`, mapping through
  `buildHistoryItems`. (Drift `.watch()` is fine in app/runtime; widget tests stub this provider
  with a finite stream, per the established Drift-watch-in-tests rule.)
- **`activeFilterCountProvider`** / **`isFilterActiveProvider`** — derived from the filter.
- **`HistoryController`** (`Provider`) — ride mutations, delegating to `RideRepository` 1:1 (and
  evicting the preview cache on delete/route-affecting edit — see below):
  ```dart
  Future<void> deleteRide(int id);              // repo.deleteById + cache.evict(id)
  Future<void> deleteRides(Iterable<int> ids);  // each: delete + evict
  Future<void> updateRideDetails(int id, String? title, String? comment, ActivityType? type);
  Future<void> toggleFavorite(Ride ride);       // repo.updateFavorite(id, !isFavorite)
  ```
  > **No `RideRepository` signature changes** — uses existing `deleteById`, `updateRideDetails`,
  > `updateRideType`, `updateFavorite`. Editing title/comment/type does **not** change the route, so
  > no preview eviction is needed there; **delete** evicts `routePreviewCacheProvider.evict(id)`.

---

## Screen — `lib/features/history/history_screen.dart` (ports `RideHistoryPage`)

`ConsumerStatefulWidget`. Local UI state mirrors the original `remember`s: `showSearch`,
`showFilterSheet`, `pendingDeleteId`, `editingRide`, `selectedEntry` (detail), `selectedIds`
(multi-select), `showBatchDelete`, `highlightRideId`, plus a `ScrollController` for jump-to-ride.

- **Top bar — two modes:**
  - **Normal** (`_HistoryFilterBar`): title `historyTitle`, a **search toggle** (search icon) that
    reveals an `TextField` (`historySearchPlaceholder`, live `setQuery`, clear ✕), and a **filter
    icon with a count badge** (`activeFilterCount`) opening the filter sheet.
  - **Selection** (`_HistorySelectionBar`, when `selectedIds` non-empty): close (✕) →
    clear selection, `selectionCount` ("N selected"), and batch-delete (trash) → confirm. **Android
    back** while selecting clears the selection instead of leaving (`PopScope`).
- **List**: `ListView` (keyed by header label / rideId), `DateHeaderItem` → uppercased dimmed label;
  `RideEntryItem` → `_HistoryRideCard`. Empty state: centered `historyEmpty`.
- **Dialogs** (overlaid): confirm-delete (single/batch), detail, edit, filter sheet.
- **Jump-to-ride**: watch `historyTargetRideProvider`; when set, find the index (reset filters first
  if the ride is filtered out, then re-run on the next emission), `animateTo` it, set
  `highlightRideId` for 1.5 s, then clear the provider. Mirrors the original `LaunchedEffect`.

### `_HistoryRideCard` (ports `RideHistoryListItem`)

A 14dp rounded `surfaceContainer` card; **2dp primary border** when selected or highlighted;
`onTap` (open detail, or toggle membership in selection mode), `onLongPress` (enter selection).

- **Thumbnail** (125dp, top-rounded): **`RoutePreview(rideId, points, cache: routePreviewCache, …)`**
  — the cached PNG (Spec 12); terrain-grid background when no route. This is the headline
  performance fix: no per-scroll tiles.
  - **Selection indicator** (check circle, top-end) in selection mode.
  - **Navigate-to-start** button (Directions icon, bottom-end, route-only, hidden in selection mode)
    → `navigationLauncherProvider.launchTo(start.lat, start.lng, title)`.
- **Body**: title (ellipsized) · favorite heart (with the 1→1.3→1 **pulse** on favoriting) ·
  distance (`%.1f`/`%.0f km`) · **3-dot (⋮) overflow menu** (`PopupMenuButton`) with **Edit** and
  **Delete** (delete tinted `deleteActionText`), hidden in selection mode.
  - **Meta** line: `formatRideTime(date) · formatDuration(durationMs) · Ø {avg} km/h`.
  - **Chips**: activity chip (icon+label, `chipSecondary`/`chipSecondaryText`); "Great pace"
    (`chipGreatPace`, avg > 10 km/h, `primaryContainer`); "No route" (`chipNoRoute`).

---

## Dialogs

### Filter bottom sheet — `_FilterSheet` (ports `FilterBottomSheet`)
`showModalBottomSheet`. Header (title `historyFilterTitle` + **Reset** text button). Sections of
`FilterChip`s (live-applying): **Period** (week/month/year/all), **Sort by**
(newest/distance/speed/duration), **Activity type** (All + each `ActivityType` with icon), and a
**Favorites-only** `Switch`. **Apply** pill just closes (filters already applied live). Selected
chip uses `primaryContainer`/`onPrimaryContainer` + 1.5dp primary border.

### Ride detail — `RideDetailDialog` (`lib/features/history/ride_detail_dialog.dart`)
Full-width rounded dialog opened on row tap:
- **Map preview** (330dp, top-rounded): `LiveMap(points: …)` with gestures, **start green / end red**
  markers (no live/current marker). A **fullscreen** button (top-end) opens a black full-screen
  dialog with the same gesture-enabled `LiveMap` + a close button. "No route" placeholder when empty.
- Date/time (`formatRideDate`), activity (icon+label) when set, title (when set), italic comment.
- Divider, then **stat rows**: Distance (`%.2f km`), Duration, Top speed (`%.1f km/h`), Avg speed
  (`%.1f km/h`). **Close** button.

### Edit ride — `EditRideDialog` (ports `EditRideDialog`)
Rounded dialog: title `editRideTitle` + subtitle `editRideSubtitle`. **Title** field (≤60 chars),
**activity chips** (re-assignable; tapping the selected one clears to null), **comment** field
(multi-line). Cancel / Save → `HistoryController.updateRideDetails(id, title, comment, type)`
(writes details **and** type). Reuses the sheet-input styling from Spec 12's summary dialog.

### Confirm delete — `ConfirmDeleteDialog` (ports `ConfirmDeleteDialog`)
Single + batch via one dialog using **ICU plurals** (`deleteRidesTitle`/`deleteRidesBody`,
count-aware). Cancel / Delete (destructive `deleteActionText`).

---

## Shell wiring — `lib/features/shell/main_shell.dart`

Replace `const _PlaceholderTab(label: 'history')` (tab index 1) with `const HistoryScreen()`. The
existing `historyTargetRideProvider` and Home's `onOpenRide` (sets the target + switches to tab 1)
are unchanged; `HistoryScreen` consumes the target. No router changes.

---

## Localization — new ARB keys (`app_en.arb` + `app_de.arb`)

Mirror the Android `history_*`, `period_*`, `sort_*`, `edit_ride_*`, `detail_*`, `chip_*`,
`activity_all`, `selection_count`, `action_*`, `a11y_*`, and the `delete_rides_confirm_*` plurals.

| Key | EN | DE |
|---|---|---|
| `historyTitle` | `Ride history` | `Fahrtenverlauf` |
| `historySearchCd` | `Search` | `Suche` |
| `historyFilterCd` | `Filter` | `Filter` |
| `historySearchPlaceholder` | `Search rides…` | `Fahrt suchen…` |
| `historyEmpty` | `No rides yet` | `Noch keine Fahrten` |
| `historyFilterTitle` | `Filter` | `Filter` |
| `historySectionPeriod` | `PERIOD` | `ZEITRAUM` |
| `historySectionSort` | `SORT BY` | `SORTIEREN NACH` |
| `historySectionActivity` | `ACTIVITY TYPE` | `AKTIVITÄT` |
| `historyFilterFavoritesOnly` | `Favorites only` | `Nur Favoriten` |
| `periodThisWeek` | `This week` | `Diese Woche` |
| `periodThisMonth` | `This month` | `Dieser Monat` |
| `periodThisYear` | `This year` | `Dieses Jahr` |
| `periodAll` | `All` | `Alle` |
| `sortNewest` | `Newest` | `Neueste` |
| `sortDistance` | `Longest distance` | `Längste Strecke` |
| `sortSpeed` | `Top speed` | `Höchstes Tempo` |
| `sortDuration` | `Shortest duration` | `Kürzeste Dauer` |
| `activityAll` | `All` | `Alle` |
| `selectionCount` | `{count} selected` | `{count} ausgewählt` |
| `editRideTitle` | `Edit ride` | `Fahrt bearbeiten` |
| `editRideSubtitle` | `Adjust title, activity and comment.` | `Titel, Aktivität und Kommentar anpassen.` |
| `editRideActivityLabel` | `Activity` | `Aktivität` |
| `detailDistanceLabel` | `Distance` | `Strecke` |
| `detailDurationLabel` | `Duration` | `Dauer` |
| `detailMaxSpeedLabel` | `Top speed` | `Höchstgeschwindigkeit` |
| `detailAvgSpeedLabel` | `Avg speed` | `Ø Geschwindigkeit` |
| `chipGreatPace` | `Great pace` | `Gutes Tempo` |
| `chipNoRoute` | `No route` | `Keine Route` |
| `actionReset` | `Reset` | `Zurücksetzen` |
| `actionApply` | `Apply` | `Anwenden` |
| `actionCancel` | `Cancel` | `Abbrechen` |
| `actionClose` | `Close` | `Schließen` |
| `actionEdit` | `Edit` | `Bearbeiten` |
| `actionDelete` | `Delete` | `Löschen` |
| `a11yMoreOptions` | `More options` | `Weitere Optionen` |
| `a11yExitSelection` | `Exit selection` | `Auswahl verlassen` |
| `a11ySelected` | `Selected` | `Ausgewählt` |
| `a11yFullscreen` | `Fullscreen` | `Vollbild` |
| `a11yNavigateToStartPoint` | `Navigate to start point` | `Zum Startpunkt navigieren` |
| `deleteRidesTitle` | `{count, plural, =1{Delete ride} other{Delete {count} rides}}` | `{count, plural, =1{Fahrt löschen} other{{count} Fahrten löschen}}` |
| `deleteRidesBody` | `{count, plural, =1{This ride and all its GPS data will be permanently deleted.} other{These {count} rides and all their GPS data will be permanently deleted.}}` | `{count, plural, =1{Diese Fahrt und alle ihre GPS-Daten werden dauerhaft gelöscht.} other{Diese {count} Fahrten und alle ihre GPS-Daten werden dauerhaft gelöscht.}}` |

**Already present — reuse, don't re-add:** `summaryTitleLabel`/`summaryCommentLabel` (edit dialog
field labels), `actionSave`, `actionSkip`, and the `activity*` names + `a11yBack`. Everything in the
table above is **new** (the `chip*`, `action(Edit/Delete/Cancel/Close)`, and `a11y*` keys don't exist
yet). `chipGreatPace` = "Great pace" / "Gutes Tempo" per the German reference table.

---

## Test-first plan (`test/history/`)

**`history_items_test.dart`** (pure pipeline — the core, heavily covered):
- Filter: favorites-only; activity type; period (week/month/year/all) using a fixed `nowMs`; search
  matches title and comment, case-insensitive, ignores blank.
- Sort: distance desc, speed desc, duration **asc**; date → grouped with `DateHeaderItem`s, days
  descending, rides within a day descending.
- `activeFilterCount` (query excluded) and `isFilterActive` (query included) across combinations.
- `startOfMonth`/week/year boundary correctness.

**`history_controller_test.dart`** (real in-memory DB): `deleteRide`/`deleteRides` remove rows
(cascade trackpoints) and call `cache.evict`; `updateRideDetails` writes description+comment+type;
`toggleFavorite` flips the flag.

**`history_screen_test.dart`** (phone-sized surface; stub `historyItemsProvider` with a finite
stream, fake `HistoryController`, `routePreviewCacheProvider` over a temp dir, `isOnlineProvider`):
- Renders date headers + ride cards (title/distance/meta/chips); empty state.
- Search toggle filters; filter sheet opens, chip selection drives the controller, badge shows count.
- Long-press enters selection; selection bar + batch-delete confirm → `deleteRides`.
- 3-dot menu → Edit opens edit dialog; Delete → confirm → `deleteRide`.
- Row tap opens the detail dialog (stats rows shown); favorite heart toggles.
- `historyTargetRideProvider` set → the target card gets the highlight border.

**`ride_detail_dialog_test.dart`** / **`edit_ride_dialog_test.dart`**: render fields/stats; edit
Save fires with entered title/comment/type; fullscreen open/close; no-route placeholder.

All gated by `flutter analyze` clean + full suite green before the phase is done.

---

## Acceptance

- History tab shows the filtered/sorted/date-grouped list with **cached-PNG thumbnails** (no
  per-scroll tiles), search, filter sheet (period/sort/activity/favorites + badge + reset), and the
  empty state.
- Per-row: favorite toggle (pulse), navigate-to-start, 3-dot edit/delete; long-press multi-select
  with selection bar + batch delete.
- Detail dialog (map + fullscreen + stats) and edit dialog (title/activity/comment) work; delete
  uses plural confirm and evicts the preview.
- Jump-to-ride from Home scrolls to + highlights the ride.
- `flutter analyze` clean; full suite green.

---

## Out of scope (later / deferred)

- Live-map gesture/rotation feel tuning → Spec 7 / device.
- The external navigation intent + fullscreen map are device-verified in Spec 15's pass (they build
  and are unit-seam-tested here via `navigationLauncherProvider`).
- Settings/profile → Spec 14; final polish/integration → Spec 15.
