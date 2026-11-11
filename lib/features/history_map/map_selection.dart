import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/heading.dart' show LatLng;
import '../../domain/outline_hit.dart';
import '../history/area_providers.dart';
import '../history/history_items.dart';
import '../history/history_providers.dart';
import 'history_map_providers.dart';
import 'route_badges.dart';

/// The rides under the last tap, nearest first, and the one shown (#96).
class MapSelection {
  const MapSelection({this.rideIds = const [], this.shownRideId});

  final List<int> rideIds;

  /// The ride whose card is shown; the first one when null or gone.
  final int? shownRideId;
}

class MapSelectionNotifier extends Notifier<MapSelection> {
  @override
  MapSelection build() => const MapSelection();

  /// Selects the rides under [tap] at map [zoom]; an empty hit clears it.
  void tap(LatLng tap, double zoom) {
    final overview = ref.read(overviewProvider).value;
    final store = ref.read(outlineStoreProvider);
    final newest = _timestamps();
    final hits = OutlineHit.find(
      tap: tap,
      zoom: zoom,
      candidates: [
        for (final id in overview?.rideIds ?? const <int>[])
          if (store.cache[id] case final entry?)
            OutlineCandidate(
              rideId: id,
              timestampMs: newest[id] ?? 0,
              bounds: entry.bounds,
              outline: () => entry.outline,
            ),
      ],
      bestRideIds: ref.read(routeBadgesProvider).value?.bestRideIds ?? const {},
    );
    state = MapSelection(rideIds: [for (final h in hits) h.rideId]);
  }

  Map<int, int> _timestamps() => {
    for (final item in ref.read(historyItemsProvider).value ?? const [])
      if (item is RideEntryItem)
        item.ride.rideId: item.ride.date ?? item.ride.startTime ?? 0,
  };

  /// Shows the card of [rideId]. Kept by ride id, so a ride dropping out of
  /// the tapped ones does not move the card to another ride.
  void show(int rideId) =>
      state = MapSelection(rideIds: state.rideIds, shownRideId: rideId);

  void clear() => state = const MapSelection();
}

final mapSelectionProvider =
    NotifierProvider<MapSelectionNotifier, MapSelection>(
      MapSelectionNotifier.new,
    );

/// A tapped ride as the preview card shows it.
class SelectedRide {
  const SelectedRide(
    this.entry, {
    required this.isBest,
    required this.groupSize,
  });

  final RideEntryItem entry;
  final bool isBest;

  /// Rides on this ride's route including itself; `1` outside any group.
  final int groupSize;
}

/// The tapped routes that still exist, in tap order, one entry per route
/// group: the group's best ride when it was hit, else its nearest hit. Rides
/// of one route show the same line, so paging through them told the rider
/// nothing; the group's other rides open from the card (#96). A ride deleted
/// while its card is open drops out; with none left the card is gone.
final selectedRidesProvider = Provider<List<SelectedRide>>((ref) {
  final selection = ref.watch(mapSelectionProvider);
  final items = ref.watch(historyItemsProvider).value ?? const [];
  final byId = {
    for (final item in items)
      if (item is RideEntryItem) item.ride.rideId: item,
  };
  final badges =
      ref.watch(routeBadgesProvider).value ?? const RouteBadges({}, {});
  // Group key -> the representative ride id, in order of first hit.
  final chosen = <int, int>{};
  for (final id in selection.rideIds) {
    if (!byId.containsKey(id)) continue;
    final key = badges.groupKeyOf(id);
    final current = chosen[key];
    if (current == null ||
        (badges.bestRideIds.contains(id) &&
            !badges.bestRideIds.contains(current))) {
      chosen[key] = id;
    }
  }
  return [
    for (final id in chosen.values)
      SelectedRide(
        byId[id]!,
        isBest: badges.bestRideIds.contains(id),
        groupSize: badges.groupSizeOf(id),
      ),
  ];
});

/// Where the shown card sits among [selectedRidesProvider]: the shown ride,
/// or the first one when it is gone.
final shownRideIndexProvider = Provider<int>((ref) {
  final rides = ref.watch(selectedRidesProvider);
  final shown = ref.watch(mapSelectionProvider.select((s) => s.shownRideId));
  final index = rides.indexWhere((r) => r.entry.ride.rideId == shown);
  return index < 0 ? 0 : index;
});
