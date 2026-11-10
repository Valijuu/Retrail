# 0001 Ride outlines for the map overview

Issue: #96. Spec: `/lib/features/history_map/history_map.sdd`, `/lib/domain/ride_outline.sdd`.

## Context

The map overview draws every saved ride at once and answers a tap on a line. Trackpoints are too heavy for
that: a ride has thousands of rows, and History already avoids joining them (#21, #20). The ride previews are
PNG files and carry no geometry. The overview needs a small, always available geometry per ride that works
offline and survives a light/dark switch.

## Decision

Each ride gets one stored outline: its trackpoints simplified to a tolerance of `5` m, written as an
encoded polyline with its bounding box, in a new table `ride_outlines` (schema version `6`).

- The table is separate from `rides`, so list queries never load the polyline text.
- The outline is built when a ride is saved. Rides saved before this version get theirs in the background,
  one at a time, the first time the map view opens; the map shows them as they arrive.
- Deleting a ride deletes its outline (`ON DELETE CASCADE`). Editing a ride does not change its route, so
  an edit keeps the outline.
- Tap hits, the heatmap points and the camera framing all work on outlines, never on trackpoints.
- One map line layer per activity type, fed by one GeoJSON source per type, not one layer per ride.
- The best time of a route comes from `@RouteGroup`; the overview never recomputes it.

## Rejected alternatives

- **Read trackpoints for every visible ride.** Simple, but thousands of rows per ride on every filter change;
  this is the cost #20 and #21 removed from the list.
- **A column on `rides`.** One table less, but the polyline text would travel with every ride list query.
- **A file cache like the previews.** Previews are keyed by brightness and re-rendered; an outline has no
  brightness, must be queryable by ride and must be deleted with the ride. The database does that for free.
- **One line per route group.** Hides how often a route was ridden and needs a stable route identity for
  rides recorded without Follow. Automatic route detection is a separate idea on the project board.
- **Satellite imagery in this feature.** Needs a second tile provider, a key and a privacy-policy change;
  tracked as a board idea (Esri World Imagery is not free without a key; MapTiler is non-commercial, #58).
