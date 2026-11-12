import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/heading.dart' show LatLng;
import '../../domain/outline_hit.dart';
import '../history/area_providers.dart';
import '../history/history_items.dart';
import 'history_map_providers.dart';
import 'map_items.dart';
import 'route_badges.dart';

/// The rides under the last tap, nearest first (#96).
class MapSelection {
  const MapSelection({this.rideIds = const []});

  final List<int> rideIds;
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
    for (final item in ref.read(mapItemsProvider).value ?? const [])
      if (item is RideEntryItem)
        item.ride.rideId: item.ride.date ?? item.ride.startTime ?? 0,
  };

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

/// The card of the tap: the nearest route's best ride (the group's best ride
/// when it was hit, else the nearest hit of that group), or null. Rides of
/// one route draw the same line, so the card shows one ride and never pages;
/// the route's other rides open from its count (#96, #109). A ride deleted
/// while its card is open, or hidden by the map's own filters, drops out.
final selectedRideProvider = Provider<SelectedRide?>((ref) {
  final selection = ref.watch(mapSelectionProvider);
  final items = ref.watch(mapItemsProvider).value ?? const [];
  final byId = {
    for (final item in items)
      if (item is RideEntryItem) item.ride.rideId: item,
  };
  final badges =
      ref.watch(routeBadgesProvider).value ?? const RouteBadges({}, {});
  final onMap = ref.watch(overviewProvider.select((o) => o.value?.rideIds));
  final onMapIds = onMap?.toSet();
  final hits = [
    for (final id in selection.rideIds)
      if (byId.containsKey(id) && (onMapIds == null || onMapIds.contains(id)))
        id,
  ];
  if (hits.isEmpty) return null;
  final key = badges.groupKeyOf(hits.first);
  final sameRoute = [
    for (final id in hits)
      if (badges.groupKeyOf(id) == key) id,
  ];
  final id = sameRoute.firstWhere(
    badges.bestRideIds.contains,
    orElse: () => sameRoute.first,
  );
  return SelectedRide(
    byId[id]!,
    isBest: badges.bestRideIds.contains(id),
    groupSize: badges.groupSizeOf(id),
  );
});
