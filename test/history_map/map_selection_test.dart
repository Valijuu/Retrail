import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/ride_outline.dart';
import 'package:retrail/features/history_map/history_map_providers.dart';
import 'package:retrail/features/history_map/map_selection.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _tap = (lat: 48.0, lng: 11.005);

Future<int> _ride(
  AppDatabase db, {
  int? followed,
  int durationMs = 1000,
  double? coverage,
  int date = 1,
}) async {
  final id = await db.rideDao.insert(
    RidesCompanion.insert(
      startTime: Value(date),
      date: Value(date),
      hasRoute: const Value(true),
      durationMs: Value(durationMs),
      distanceMetres: const Value(100),
      avgSpeedKmh: const Value(10),
      maxSpeedKmh: const Value(20),
      followedRideId: Value(followed),
      followCoverage: Value(coverage),
    ),
  );
  final o = RideOutline([(lat: 48.0, lng: 11.0), (lat: 48.0, lng: 11.01)]);
  final b = o.bounds!;
  await db.outlineDao.upsert(
    RideOutlinesCompanion.insert(
      rideId: Value(id),
      polyline: o.encode(),
      south: b.south,
      west: b.west,
      north: b.north,
      east: b.east,
    ),
  );
  return id;
}

void main() {
  late AppDatabase db;
  late ProviderContainer c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        preferencesRepositoryProvider.overrideWithValue(
          PreferencesRepository(prefs),
        ),
      ],
    );
    c.listen(overviewProvider, (_, _) {});
    c.listen(selectedRideProvider, (_, _) {});
    c.listen(routeBadgesProvider, (_, _) {});
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 600));

  test(
    'tapping an overlapping stretch gives one card: the nearest route\'s best ride',
    () async {
      final original = await _ride(db, durationMs: 900, date: 1);
      final follow = await _ride(
        db,
        followed: original,
        durationMs: 800,
        coverage: 1,
        date: 2,
      );
      final other = await _ride(db, date: 1);
      await settle();

      c.read(mapSelectionProvider.notifier).tap(_tap, 14);
      // The original and its follow are one route: one card, the best ride.
      final card = c.read(selectedRideProvider)!;
      expect(card.entry.ride.rideId, follow);
      expect(card.isBest, isTrue);
      expect(card.groupSize, 2);
      expect(card.entry.ride.rideId, isNot(original));
      expect(card.entry.ride.rideId, isNot(other));
    },
  );

  test('tapping empty map clears the selection', () async {
    await _ride(db);
    await settle();
    final n = c.read(mapSelectionProvider.notifier)..tap(_tap, 14);
    expect(c.read(selectedRideProvider), isNotNull);
    n.tap((lat: 49.0, lng: 11.005), 14);
    expect(c.read(selectedRideProvider), isNull);
  });

  test(
    'deleting a ride shown in the open card closes it and drops its cache',
    () async {
      final id = await _ride(db);
      await settle();
      c.read(mapSelectionProvider.notifier).tap(_tap, 14);
      expect(c.read(selectedRideProvider), isNotNull);

      await db.rideDao.deleteById(id);
      await settle();

      expect(c.read(selectedRideProvider), isNull);
      expect(c.read(overviewProvider).value!.rideIds, isEmpty);
      expect(await db.select(db.rideOutlines).get(), isEmpty);
    },
  );

  test(
    'deleting the best ride of a group recomputes the best without it',
    () async {
      final original = await _ride(db, durationMs: 900, date: 1);
      final follow = await _ride(
        db,
        followed: original,
        durationMs: 800,
        coverage: 1,
        date: 2,
      );
      await settle();
      expect(c.read(routeBadgesProvider).value!.bestRideIds, {follow});

      await db.rideDao.deleteById(follow);
      await settle();
      expect(c.read(routeBadgesProvider).value!.bestRideIds, isEmpty);
    },
  );

  test('the card moves to another hit when its ride is deleted', () async {
    final a = await _ride(db, date: 1);
    final b = await _ride(db, date: 2);
    await settle();
    c.read(mapSelectionProvider.notifier).tap(_tap, 14);
    final shown = c.read(selectedRideProvider)!.entry.ride.rideId;
    await db.rideDao.deleteById(shown);
    await settle();
    expect(c.read(selectedRideProvider)!.entry.ride.rideId, shown == a ? b : a);
  });
}
