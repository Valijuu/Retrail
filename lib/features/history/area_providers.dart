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

  /// Drops the outlines of rides that are gone and loads, in one query,
  /// those of [wanted] that are outlined ([revisions]: ride id → revision)
  /// but not cached yet or cached at an older revision (#111).
  Future<void> refresh(Map<int, int> revisions, Iterable<int> wanted) async {
    cache.sync(revisions.keys.toSet());
    final missing = [
      for (final id in wanted)
        if (revisions[id] case final revision?)
          if (cache[id]?.row.revision != revision) id,
    ];
    if (missing.isEmpty) return;
    final List<RideOutlineRow> rows = await _repo.load(missing);
    cache.addRows(rows);
  }
}

final outlineStoreProvider = Provider<OutlineStore>(
  (ref) => OutlineStore(ref.watch(outlineRepositoryProvider)),
);

/// Ride id → revision of every ride that has an outline row (#111).
final outlineRevisionsProvider = StreamProvider<Map<int, int>>(
  (ref) => ref.watch(outlineRepositoryProvider).watchOutlineRevisions(),
);
