import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show RideOutlineRow;
import '../../data/repositories/data_providers.dart';
import '../../data/repositories/outline_repository.dart';
import 'outline_cache.dart';

/// Filter changes and the radius slider settle this long before the rides
/// are worked out again (#96).
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
