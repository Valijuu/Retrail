import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show RideOutlineRow;
import '../../domain/area_filter.dart';
import '../../data/repositories/data_providers.dart';
import '../../data/repositories/outline_repository.dart';
import 'history_providers.dart';
import 'outline_cache.dart';

/// Filter changes and the radius slider settle this long before the rides
/// inside the area are worked out (#96).
const filterDebounce = Duration(milliseconds: 150);

/// The in-memory outlines (#96): loaded from the database on demand and kept
/// in step with the rides that have one.
class OutlineStore {
  OutlineStore(this._repo);

  final OutlineRepository _repo;
  final OutlineCache cache = OutlineCache();

  /// Drops the outlines of rides that are gone and loads those of [wanted]
  /// that are outlined ([outlinedIds]) but not cached yet, in one query.
  Future<void> refresh(Set<int> outlinedIds, Iterable<int> wanted) async {
    cache.sync(outlinedIds);
    final missing = [
      for (final id in wanted)
        if (outlinedIds.contains(id) && cache[id] == null) id,
    ];
    if (missing.isEmpty) return;
    final List<RideOutlineRow> rows = await _repo.load(missing);
    cache.addRows(rows);
  }
}

final outlineStoreProvider = Provider<OutlineStore>(
  (ref) => OutlineStore(ref.watch(outlineRepositoryProvider)),
);

/// The ids of the rides that have an outline row.
final outlinedRideIdsProvider = StreamProvider<Set<int>>(
  (ref) => ref.watch(outlineRepositoryProvider).watchOutlinedRideIds(),
);

/// The History area filter once its changes have settled: a long press or
/// the radius slider moves it often, the work behind it should not (#96).
/// Removing the area applies at once.
class SettledAreaNotifier extends Notifier<AreaFilter?> {
  Timer? _timer;

  @override
  AreaFilter? build() {
    ref.onDispose(() => _timer?.cancel());
    ref.listen(historyFilterProvider.select((f) => f.area), (_, next) {
      _timer?.cancel();
      if (next == null) {
        state = null;
        return;
      }
      _timer = Timer(filterDebounce, () => state = next);
    });
    return ref.read(historyFilterProvider).area;
  }
}

final settledAreaProvider = NotifierProvider<SettledAreaNotifier, AreaFilter?>(
  SettledAreaNotifier.new,
);

/// The rides whose outline comes within the History area filter; null while
/// no area is set. A ride without an outline is not among them (#96).
final areaRideIdsProvider = FutureProvider<Set<int>?>((ref) async {
  final area = ref.watch(settledAreaProvider);
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
