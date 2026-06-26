import '../../data/db/ride_with_trackpoints.dart';
import '../../domain/distance_calculator.dart';
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

/// A ride with its computed [RideStats].
class RideEntryItem extends HistoryItem {
  const RideEntryItem(this.rwt, this.stats);
  final RideWithTrackpoints rwt;
  final RideStats stats;
}

/// Filters, sorts and (for date sort) date-groups the history into a flat
/// display list. Pure — mirrors `RideHistoryViewModel.ridesWithStats`, so the
/// distance/speed/duration sorts run over trackpoint-derived stats.
List<HistoryItem> buildHistoryItems(
  List<RideWithTrackpoints> rides,
  HistoryFilter f, {
  required DistanceCalculator calc,
  int? nowMs,
  String? locale,
}) {
  final periodStart = switch (f.period) {
    TimePeriod.thisWeek => weekBounds(nowMs: nowMs).$1,
    TimePeriod.thisMonth => monthBounds(nowMs: nowMs).$1,
    TimePeriod.thisYear => yearBounds(nowMs: nowMs).$1,
    TimePeriod.all => 0,
  };
  final trimmedQuery = f.query.trim();

  final entries = rides
      .where((rwt) => !f.favoritesOnly || rwt.ride.isFavorite)
      .where((rwt) => f.activity == null || rwt.ride.typ == f.activity!.id)
      .where((rwt) {
        final ts = rwt.ride.date ?? rwt.ride.startTime ?? 0;
        return periodStart == 0 || ts >= periodStart;
      })
      .where((rwt) {
        if (trimmedQuery.isEmpty) return true;
        final q = trimmedQuery.toLowerCase();
        final title = rideDisplayTitle(rwt.ride, locale: locale, nowMs: nowMs);
        return title.toLowerCase().contains(q) ||
            (rwt.ride.comment?.toLowerCase().contains(q) ?? false);
      })
      .map((rwt) => RideEntryItem(rwt, computeRideStats(rwt, calc)))
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

/// Groups entries by day (newest day first), each preceded by a date header;
/// rides within a day are date-descending. Mirrors `groupByDate`.
List<HistoryItem> _groupByDate(List<RideEntryItem> entries) {
  final byDay = <String, List<RideEntryItem>>{};
  for (final e in entries) {
    final key = formatRideDayKey(e.rwt.ride.date);
    (byDay[key] ??= []).add(e);
  }
  final dayKeys = byDay.keys.toList()..sort((a, b) => b.compareTo(a));

  final out = <HistoryItem>[];
  for (final key in dayKeys) {
    out.add(DateHeaderItem(key));
    final dayEntries = byDay[key]!
      ..sort((a, b) => (b.rwt.ride.date ?? 0).compareTo(a.rwt.ride.date ?? 0));
    out.addAll(dayEntries);
  }
  return out;
}
