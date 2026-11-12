import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../history/history_filter.dart';
import '../history/history_items.dart';
import '../history/history_providers.dart';
import '../history/history_range.dart';
import '../settings/settings_providers.dart' show dateFormatLocaleProvider;

/// The filter the map uses of the History header (#113): search, year, months,
/// favourites and followed routes. The activity filter and the sort order of
/// the header are the list's alone; the map has its own activity menu.
HistoryFilter mapHeaderFilter(HistoryFilter f) =>
    f.copyWith(activities: const {}, sort: SortOrder.date);

/// Whether the header filters the map uses hide rides from it (the search
/// text counts here, unlike in the filter badge).
bool mapHeaderFilterNarrows(HistoryFilter f) =>
    narrowsRides(mapHeaderFilter(f));

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

/// How many rides with a route the history has, before any filter: the
/// total in "12 of 40 rides".
final routedRideCountProvider = StreamProvider<int>(
  (ref) => ref
      .watch(rideRepositoryProvider)
      .getAllRides()
      .map((rides) => rides.where((r) => r.hasRoute).length),
);

/// The filter badge in the map view: only the header filters the map uses
/// (the list's sort and activity filter do not count there).
final activeMapFilterCountProvider = Provider<int>(
  (ref) => activeFilterCount(mapHeaderFilter(ref.watch(historyFilterProvider))),
);
