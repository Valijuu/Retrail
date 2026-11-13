import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../history/history_filter.dart';
import '../history/history_items.dart';
import '../history/history_providers.dart';
import '../history/history_range.dart';
import 'history_map_providers.dart'
    show routeBadgesProvider, settledMapRidesProvider;
import 'route_badges.dart';
import '../settings/settings_providers.dart' show dateFormatLocaleProvider;

/// The filter the map uses of the History header (#113): search, year, months,
/// favourites and followed routes. The activity filter and the sort order of
/// the header are the list's alone; the map has its own activity menu.
HistoryFilter mapHeaderFilter(HistoryFilter f) =>
    f.copyWith(activities: const {}, sort: SortOrder.date);

/// The rides the map starts from: the History items under the header filters
/// the map uses (see [mapHeaderFilter]). The list keeps [historyItemsProvider].
final mapItemsProvider = StreamProvider<List<HistoryItem>>((ref) {
  final filter = mapHeaderFilter(ref.watch(historyFilterProvider));
  final locale = ref.watch(dateFormatLocaleProvider);
  final repo = ref.watch(rideRepositoryProvider);
  final (start, end) = effectiveRange(filter);
  return repo
      .getRidesInRange(startMs: start, endMs: end)
      .map((rides) => buildHistoryItems(rides, filter, locale: locale));
});

/// How many different routes [rideIds] make up: a followed ride counts with
/// its original (#113). Without [badges] every ride counts on its own.
int uniqueRoutes(Iterable<int> rideIds, RouteBadges? badges) =>
    {for (final id in rideIds) badges?.groupKeyOf(id) ?? id}.length;

/// How many different routes the history has, before any filter: the total
/// in "12 of 40 rides".
final routedRideCountProvider = StreamProvider<int>((ref) {
  final badges = ref.watch(routeBadgesProvider).value;
  return ref
      .watch(rideRepositoryProvider)
      .getAllRides()
      .map(
        (rides) => uniqueRoutes([
          for (final r in rides)
            if (r.hasRoute) r.rideId,
        ], badges),
      );
});

/// The filter badge in the map view: only the header filters the map uses
/// (the list's sort and activity filter do not count there).
final activeMapFilterCountProvider = Provider<int>(
  (ref) => activeFilterCount(mapHeaderFilter(ref.watch(historyFilterProvider))),
);

/// "10 of 52 rides" in the activity button: the unique routes the map draws
/// and the unique routes the history has (#113).
final mapRideCountsProvider = Provider<({int shown, int total})>((ref) {
  final badges = ref.watch(routeBadgesProvider).value;
  final shown = uniqueRoutes(
    ref.watch(settledMapRidesProvider).map((r) => r.rideId),
    badges,
  );
  return (shown: shown, total: ref.watch(routedRideCountProvider).value ?? 0);
});
