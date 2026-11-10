import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show RideOutlineRow;
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

/// The rides whose outline comes within the History area filter; null while
/// no area is set. A ride without an outline is not among them (#96).
final areaRideIdsProvider = FutureProvider<Set<int>?>((ref) async {
  final area = ref.watch(historyFilterProvider.select((f) => f.area));
  if (area == null) return null;
  await Future<void>.delayed(filterDebounce);
  final ids = await ref.watch(outlinedRideIdsProvider.future);
  if (!ref.mounted) return const {};
  final store = ref.read(outlineStoreProvider);
  await store.refresh(ids, ids);
  return {
    for (final id in ids)
      if (store.cache[id] case final entry?)
        if (!entry.isEmpty && area.matches(entry.outline)) id,
  };
});
