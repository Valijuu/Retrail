import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history_map/outline_fill.dart';

class _Foreground extends AppForegroundNotifier {
  _Foreground(this.value);
  final bool value;

  @override
  bool build() => value;
}

Future<void> _oldRide(AppDatabase db) async {
  final id = await db.rideDao.insert(
    RidesCompanion.insert(
      startTime: const Value(1),
      hasRoute: const Value(true),
    ),
  );
  for (var i = 0; i < 3; i++) {
    await db.trackpointDao.insert(
      TrackpointsCompanion.insert(
        rideId: id,
        latitude: 48,
        longitude: 11 + i * 0.001,
        timestamp: i,
      ),
    );
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    await _oldRide(db);
    await _oldRide(db);
  });
  tearDown(() => db.close());

  ProviderContainer container({bool foreground = true}) {
    final c = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appForegroundProvider.overrideWith(() => _Foreground(foreground)),
      ],
    );
    addTearDown(c.dispose);
    c.listen(outlineFillProvider, (_, _) {});
    return c;
  }

  Future<int> outlineCount() async => (await db.outlineDao.getAll()).length;

  test(
    'nothing is filled while neither the map nor an area is shown',
    () async {
      container();
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(await outlineCount(), 0);
    },
  );

  test('showing the map fills every old ride, one at a time', () async {
    final c = container();
    c.read(mapVisibleProvider.notifier).set(true);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await outlineCount(), 2);
    expect(c.read(outlineFillProvider), isFalse);
  });

  test('setting an area starts the fill without the map', () async {
    final c = container();
    c.read(historyFilterProvider.notifier).setAreaPin((lat: 48.0, lng: 11.0));
    await Future<void>.delayed(const Duration(milliseconds: 500));
    expect(await outlineCount(), 2);
  });

  test('the fill does not run while the app is in the background', () async {
    final c = container(foreground: false);
    c.read(mapVisibleProvider.notifier).set(true);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(await outlineCount(), 0);
  });
}
