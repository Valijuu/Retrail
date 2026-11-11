import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/area_filter.dart';
import '../../domain/heading.dart' show LatLng;
import '../history/area_providers.dart';

/// "Rides around here" on the map (#96): a pin and a radius. It belongs to
/// the map alone, like the activity selection: the History list and its
/// filter badge do not know it, and it is not stored across app starts.
class MapAreaNotifier extends Notifier<AreaFilter?> {
  @override
  AreaFilter? build() => null;

  /// Pins the area at [pin]; a radius chosen before stays.
  void setPin(LatLng pin) =>
      state = state?.copyWith(pin: pin) ?? AreaFilter(pin: pin);

  /// Sets the radius in km (clamped); does nothing without a pin.
  void setRadius(double radiusKm) {
    final area = state;
    if (area != null) state = area.copyWith(radiusKm: radiusKm);
  }

  void clear() => state = null;
}

final mapAreaProvider = NotifierProvider<MapAreaNotifier, AreaFilter?>(
  MapAreaNotifier.new,
);

/// The map's area once its changes have settled: a long press or the radius
/// slider moves it often, the work behind it should not. Removing the area
/// applies at once.
class SettledMapAreaNotifier extends Notifier<AreaFilter?> {
  Timer? _timer;

  @override
  AreaFilter? build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(mapAreaProvider, (_, next) {
      _timer?.cancel();
      if (next == null) {
        state = null;
        return;
      }
      _timer = Timer(filterDebounce, () => state = next);
    });
    return ref.read(mapAreaProvider);
  }
}

final settledMapAreaProvider =
    NotifierProvider<SettledMapAreaNotifier, AreaFilter?>(
      SettledMapAreaNotifier.new,
    );

/// The rides whose outline comes within the map's area; null while no area is
/// set. A ride without an outline is not among them.
final mapAreaRideIdsProvider = FutureProvider<Set<int>?>((ref) async {
  final area = ref.watch(settledMapAreaProvider);
  if (area == null) return null;
  final ids = await ref.watch(outlinedRideIdsProvider.future);
  final store = ref.read(outlineStoreProvider);
  await store.refresh(ids, ids);
  if (!ref.mounted) return const {};
  return {
    for (final id in ids)
      if (store.cache[id] case final entry?)
        if (!entry.isEmpty &&
            area.couldReach(entry.bounds) &&
            area.matches(entry.outline))
          id,
  };
});
