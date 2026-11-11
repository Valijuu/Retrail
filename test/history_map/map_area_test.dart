import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/domain/ride_outline.dart';
import 'package:retrail/features/history_map/map_area.dart';

/// A ride whose outline is a short line [km] north of the origin.
Future<int> _ride(AppDatabase db, double km) async {
  final id = await db.rideDao.insert(
    RidesCompanion.insert(
      startTime: const Value(1),
      hasRoute: const Value(true),
    ),
  );
  final lat = km / 111.195;
  final outline = RideOutline([(lat: lat, lng: 0.0), (lat: lat, lng: 0.01)]);
  final box = outline.bounds!;
  await db.outlineDao.upsert(
    RideOutlinesCompanion.insert(
      rideId: Value(id),
      polyline: outline.encode(),
      south: box.south,
      west: box.west,
      north: box.north,
      east: box.east,
    ),
  );
  return id;
}

Future<Set<int>?> _settle(ProviderContainer c) async {
  final sub = c.listen(mapAreaRideIdsProvider, (_, _) {});
  addTearDown(sub.close);
  await Future<void>.delayed(const Duration(milliseconds: 400));
  return c.read(mapAreaRideIdsProvider).value;
}

void main() {
  late AppDatabase db;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase.memory();
    c = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  test('without an area there is no restriction', () async {
    await _ride(db, 1);
    expect(await _settle(c), isNull);
  });

  test('with an area only the rides within the radius remain', () async {
    final near = await _ride(db, 3);
    await _ride(db, 40);
    c.read(mapAreaProvider.notifier).setPin((lat: 0.0, lng: 0.0));
    expect(await _settle(c), {near});
  });

  test('a larger radius lets more rides in', () async {
    final near = await _ride(db, 3);
    final far = await _ride(db, 40);
    c.read(mapAreaProvider.notifier)
      ..setPin((lat: 0.0, lng: 0.0))
      ..setRadius(50);
    expect(await _settle(c), {near, far});
  });

  test('a ride with an empty outline never matches', () async {
    final id = await db.rideDao.insert(
      RidesCompanion.insert(hasRoute: const Value(true)),
    );
    await db.outlineDao.upsert(
      RideOutlinesCompanion.insert(
        rideId: Value(id),
        polyline: '',
        south: 0,
        west: 0,
        north: 0,
        east: 0,
      ),
    );
    c.read(mapAreaProvider.notifier).setPin((lat: 0.0, lng: 0.0));
    expect(await _settle(c), isEmpty);
  });

  test('the pin keeps a chosen radius when it moves', () {
    final n = c.read(mapAreaProvider.notifier)..setPin((lat: 48.1, lng: 11.5));
    expect(c.read(mapAreaProvider)!.radiusKm, 5);
    n
      ..setRadius(12)
      ..setPin((lat: 49, lng: 12));
    final area = c.read(mapAreaProvider)!;
    expect((area.pin, area.radiusKm), ((lat: 49.0, lng: 12.0), 12));
  });

  test('a radius without a pin does nothing, clearing removes the area', () {
    final n = c.read(mapAreaProvider.notifier)..setRadius(12);
    expect(c.read(mapAreaProvider), isNull);
    n
      ..setPin((lat: 1, lng: 2))
      ..clear();
    expect(c.read(mapAreaProvider), isNull);
  });
}
