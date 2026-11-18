import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/outline_repository.dart';
import 'package:retrail/features/history/area_providers.dart';

void main() {
  late AppDatabase db;
  late OutlineStore store;

  setUp(() {
    db = AppDatabase.memory();
    store = OutlineStore(OutlineRepository(db.outlineDao, db.trackpointDao));
  });
  tearDown(() => db.close());

  Future<int> ride() => db.rideDao.insert(
    RidesCompanion.insert(
      startTime: const Value(1),
      hasRoute: const Value(true),
    ),
  );

  Future<void> write(int id, double south) => db.outlineDao.upsert(
    RideOutlinesCompanion.insert(
      rideId: Value(id),
      polyline: 'p$south',
      south: south,
      west: 2,
      north: 3,
      east: 4,
    ),
  );

  Future<Map<int, int>> revisions() =>
      db.outlineDao.watchOutlineRevisions().first;

  test('a rewritten outline of a cached ride is loaded again (#111)', () async {
    final id = await ride();
    await write(id, 1);
    await store.refresh(await revisions(), [id]);
    expect(store.cache[id]!.row.south, 1);

    await write(id, 0.5);
    await store.refresh(await revisions(), [id]);
    expect(store.cache[id]!.row.south, 0.5);
  });

  test('an unchanged cached outline keeps its entry', () async {
    final id = await ride();
    await write(id, 1);
    await store.refresh(await revisions(), [id]);
    final entry = store.cache[id];
    await store.refresh(await revisions(), [id]);
    expect(store.cache[id], same(entry));
  });

  test('a ride whose outline is gone leaves the cache', () async {
    final id = await ride();
    await write(id, 1);
    await store.refresh(await revisions(), [id]);
    await db.rideDao.deleteById(id);
    await store.refresh(await revisions(), [id]);
    expect(store.cache[id], isNull);
  });
}
