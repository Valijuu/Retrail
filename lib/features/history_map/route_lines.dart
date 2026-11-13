import 'dart:isolate';

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../../domain/ride_outline.dart';
import '../../domain/route_match.dart';
import '../history/area_providers.dart';
import 'route_badges.dart';

/// The rides with a route and the ride each follows (#114); changes when a
/// ride is added or removed or a follow link is written.
final _routedFollowsProvider = StreamProvider<Map<int, int?>>(
  (ref) => ref
      .watch(rideRepositoryProvider)
      .getAllRides()
      .map(
        (rides) => {
          for (final r in rides)
            if (r.hasRoute) r.rideId: r.followedRideId,
        },
      )
      .distinct(mapEquals),
);

/// How long the lines wait for further changes before they are matched: an
/// outline backfill changes the inputs ride by ride.
final routeLinesDebounceProvider = Provider<Duration>(
  (ref) => const Duration(milliseconds: 500),
);

/// Which rides lie on the same line, by ride id → group key (#114): every
/// ride with a route, grouped by geometry and by follow links, off the UI
/// thread. Null while it is being built; callers fall back to the follow
/// groups of [RouteBadges] until then.
final routeLineKeysProvider = FutureProvider<Map<int, int>>((ref) async {
  final outlined = ref.watch(outlinedRideIdsProvider).value ?? const <int>{};
  final follows = ref.watch(_routedFollowsProvider).value;
  if (follows == null) return const {};
  // Changed inputs dispose this run: only the last one matches.
  await Future<void>.delayed(ref.read(routeLinesDebounceProvider));
  if (!ref.mounted) return const {};
  final store = ref.read(outlineStoreProvider);
  await store.refresh(outlined, follows.keys);
  if (!ref.mounted) return const {};
  final request = [
    for (final MapEntry(key: id, value: followed) in follows.entries)
      (
        id: id,
        followed: followed,
        polyline: store.cache[id]?.isEmpty == false
            ? store.cache[id]!.row.polyline
            : '',
        bounds: store.cache[id]?.isEmpty == false
            ? store.cache[id]!.bounds
            : null,
      ),
  ];
  return Isolate.run(() => _match(request));
});

Map<int, int> _match(
  List<({int id, int? followed, String polyline, OutlineBounds? bounds})>
  request,
) => RouteMatch.groups([
  for (final r in request)
    RouteMatchEntry(
      rideId: r.id,
      followedRideId: r.followed,
      bounds: r.bounds,
      points: r.polyline.isEmpty
          ? const []
          : RideOutline.decode(r.polyline).points,
    ),
]);

/// The route key of [rideId]: its line group once known, else its follow
/// group, else itself.
int routeKeyOf(int rideId, Map<int, int>? lines, RouteBadges? badges) =>
    lines?[rideId] ?? badges?.groupKeyOf(rideId) ?? rideId;

/// Rides on [rideId]'s route, itself included.
int routeSizeOf(int rideId, Map<int, int>? lines, RouteBadges? badges) {
  final key = lines?[rideId];
  if (key == null) return badges?.groupSizeOf(rideId) ?? 1;
  return lines!.values.where((k) => k == key).length;
}
