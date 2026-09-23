import '../../data/db/app_database.dart' show Ride;
import '../../domain/formatters.dart';
import '../../domain/ride_stats.dart';
import '../../domain/ride_title.dart';
import '../../domain/time_bounds.dart';
import 'history_filter.dart';

export '../../domain/formatters.dart' show formatRideDayKey, formatDateLabel;

/// One row in the rendered history list: a date header or a ride entry.
sealed class HistoryItem {
  const HistoryItem();
}

/// A day-group header carrying the `yyyy-MM-dd` day key. The UI localizes it via
/// [formatDateLabel] (Today / Yesterday / "14. Juni"). Only present for date sort.
class DateHeaderItem extends HistoryItem {
  const DateHeaderItem(this.dayKey);
  final String dayKey;
}

/// A ride with its computed [RideStats]. No trackpoints — the list query
/// doesn't join them (see issue #21); a card fetches its own, lazily, only
/// to render a not-yet-cached route preview (HistoryRideCard/_Thumbnail).
class RideEntryItem extends HistoryItem {
  const RideEntryItem(this.ride, this.stats);
  final Ride ride;
  final RideStats stats;
}

/// Filters, sorts and (for date sort) date-groups the history into a flat
/// display list. Pure — mirrors `RideHistoryViewModel.ridesWithStats`. Stats
/// come off the ride row (denormalized at save time, see
/// `RideRepository.updateEndTime`), falling back to a duration-only estimate
/// for the rare row without them yet — see [storedRideStats].
List<HistoryItem> buildHistoryItems(
  List<Ride> rides,
  HistoryFilter f, {
  int? nowMs,
  String? locale,
}) {
  // Multi-select activities: a ride matches ANY selected type; empty = all.
  final activityIds = {for (final a in f.activities) a.id};
  final trimmedQuery = f.query.trim();

  final hasMonthRange = f.monthFrom != null || f.monthTo != null;

  final entries = rides
      .where((ride) => !f.favoritesOnly || ride.isFavorite)
      .where((ride) => activityIds.isEmpty || activityIds.contains(ride.typ))
      .where((ride) {
        if (!hasMonthRange) return true;
        // A concrete `year` already narrows the DB query to exactly this
        // month range for that year (see `effectiveRange`), so this check is
        // redundant-but-harmless there. It's load-bearing for "All years"
        // (year == null): `effectiveRange` can't express "these months, every
        // year" as a single (start, end) window, so the cross-year
        // restriction is applied here instead, over the unrestricted fetch.
        final ts = ride.date ?? ride.startTime;
        return ts != null &&
            monthOfYearInRange(ts, monthFrom: f.monthFrom, monthTo: f.monthTo);
      })
      .where((ride) {
        if (trimmedQuery.isEmpty) return true;
        final q = trimmedQuery.toLowerCase();
        final title = rideDisplayTitle(ride, locale: locale, nowMs: nowMs);
        return title.toLowerCase().contains(q) ||
            (ride.comment?.toLowerCase().contains(q) ?? false);
      })
      .map((ride) => RideEntryItem(
          ride, storedRideStats(ride) ?? statsWithoutTrackpoints(ride)))
      .toList();

  switch (f.sort) {
    case SortOrder.date:
      return _groupByDate(entries);
    case SortOrder.distance:
      entries.sort(
          (a, b) => b.stats.distanceMetres.compareTo(a.stats.distanceMetres));
      return entries;
    case SortOrder.speed:
      entries.sort((a, b) => b.stats.maxSpeedKmh.compareTo(a.stats.maxSpeedKmh));
      return entries;
    case SortOrder.duration:
      entries.sort((a, b) => a.stats.durationMs.compareTo(b.stats.durationMs));
      return entries;
  }
}

/// Estimated scroll offset of [rideId]'s card in the rendered history list.
/// Rough per-item extents are fine — the estimate only needs to land within
/// the list's cache extent so the target card gets BUILT; the jump-to-ride
/// flow then fine-tunes with `Scrollable.ensureVisible`. Returns 0 when the
/// ride isn't in [items].
double estimatedOffsetOf(
  List<HistoryItem> items,
  int rideId, {
  double headerExtent = 42,
  double cardExtent = 240,
}) {
  var offset = 0.0;
  for (final item in items) {
    if (item is RideEntryItem && item.ride.rideId == rideId) return offset;
    offset += item is DateHeaderItem ? headerExtent : cardExtent;
  }
  return 0;
}

/// Groups entries by day (newest day first), each preceded by a date header;
/// rides within a day are date-descending. Mirrors `groupByDate`.
List<HistoryItem> _groupByDate(List<RideEntryItem> entries) {
  final byDay = <String, List<RideEntryItem>>{};
  for (final e in entries) {
    final key = formatRideDayKey(e.ride.date);
    (byDay[key] ??= []).add(e);
  }
  final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  final out = <HistoryItem>[];
  for (final key in dayKeys) {
    out.add(DateHeaderItem(key));
    final dayEntries = byDay[key]!
      ..sort((a, b) => (b.ride.date ?? 0).compareTo(a.ride.date ?? 0));
    out.addAll(dayEntries);
  }
  return out;
}
