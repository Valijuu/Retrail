import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../../domain/ride_outline.dart';
import '../../domain/route_match.dart';
import '../history/area_providers.dart';
import 'route_badges.dart';

/// Which rides lie on the same line, by ride id → group key (#114): every
/// ride with an outline, grouped by geometry and by follow links, off the UI
/// thread. Null while it is being built; callers fall back to the follow
/// groups of [RouteBadges] until then.
final routeLineKeysProvider = FutureProvider<Map<int, int>>((ref) async {
  final outlined = ref.watch(outlinedRideIdsProvider).value ?? const <int>{};
  final rides = await ref.watch(rideRepositoryProvider).getAllRides().first;
  if (!ref.mounted) return const {};
  final store = ref.read(outlineStoreProvider);
  final ids = [
    for (final r in rides)
      if (r.hasRoute && outlined.contains(r.rideId)) r.rideId,
  ];
  await store.refresh(outlined, ids);
  if (!ref.mounted) return const {};
  final follows = {for (final r in rides) r.rideId: r.followedRideId};
  final request = [
    for (final id in ids)
      if (store.cache[id] case final e? when !e.isEmpty)
        (
          id: id,
          followed: follows[id],
          polyline: e.row.polyline,
          bounds: e.bounds,
        ),
  ];
  return Isolate.run(() => _match(request));
});

Map<int, int> _match(
  List<({int id, int? followed, String polyline, OutlineBounds bounds})>
  request,
) => RouteMatch.groups([
  for (final r in request)
    RouteMatchEntry(
      rideId: r.id,
      followedRideId: r.followed,
      bounds: r.bounds,
      points: RideOutline.decode(r.polyline).points,
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
