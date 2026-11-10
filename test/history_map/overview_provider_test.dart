import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/ride_outline.dart';
import 'package:retrail/features/history/area_providers.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history_map/history_map_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<int> _ride(
  AppDatabase db, {
  String? type = 'LONGBOARD',
  bool outline = true,
  double lat = 48,
}) async {
  final id = await db.rideDao.insert(
    RidesCompanion.insert(
      typ: Value(type),
      startTime: const Value(1),
      date: const Value(1),
      hasRoute: const Value(true),
    ),
  );
  if (outline) {
    final o = RideOutline([(lat: lat, lng: 11.0), (lat: lat, lng: 11.01)]);
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
  }
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
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<OverviewState> settle() async {
    final sub = c.listen(overviewProvider, (_, _) {});
    addTearDown(sub.close);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    return c.read(overviewProvider).value!;
  }

  test('only rides with an outline are visible', () async {
    final a = await _ride(db);
    await _ride(db, outline: false);
    final state = await settle();
    expect(state.rideIds, [a]);
    expect(state.data!.linesByType.keys, ['LONGBOARD']);
    expect(state.bounds!.south, 48);
  });

  test('the activity filter changes list and map alike', () async {
    await _ride(db, type: 'LONGBOARD');
    final ski = await _ride(db, type: 'SKI');
    c.read(historyFilterProvider.notifier).toggleActivity(ActivityType.ski);
    final state = await settle();
    expect(state.rideIds, [ski]);
    expect(state.data!.linesByType.keys, ['SKI']);
  });

  test('heat mode builds the heat points and no lines', () async {
    await _ride(db);
    await c.read(historyMapControllerProvider).setMode(HistoryMapMode.heat);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final state = await settle();
    expect(state.mode, HistoryMapMode.heat);
    expect(state.data!.linesByType, isEmpty);
    expect(state.data!.heat, contains('MultiPoint'));
  });

  test('a ride deleted from the history leaves the map', () async {
    final a = await _ride(db);
    final b = await _ride(db);
    expect((await settle()).rideIds, unorderedEquals([a, b]));
    await db.rideDao.deleteById(a);
    await Future<void>.delayed(const Duration(milliseconds: 600));
    final state = c.read(overviewProvider).value!;
    expect(state.rideIds, [b]);
    expect(c.read(outlineStoreProvider).cache[a], isNull);
  });

  test('equal visible sets are equal, so the map is not pushed again', () {
    const a = OverviewState(
      mode: HistoryMapMode.lines,
      rideIds: [1, 2],
      data: null,
      bounds: null,
    );
    const b = OverviewState(
      mode: HistoryMapMode.lines,
      rideIds: [1, 2],
      data: null,
      bounds: null,
    );
    expect(a, b);
    expect(
      a ==
          const OverviewState(
            mode: HistoryMapMode.lines,
            rideIds: [1],
            data: null,
            bounds: null,
          ),
      isFalse,
    );
  });
}
