import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/features/history/history_items.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history/route_group_providers.dart';
import 'package:retrail/features/settings/settings_providers.dart';

/// The first non-loading value of [p], listening so the Drift stream runs.
Future<T> firstData<T>(
  ProviderContainer c,
  ProviderListenable<AsyncValue<T>> p,
) {
  final completer = Completer<T>();
  final sub = c.listen<AsyncValue<T>>(p, (_, next) {
    next.whenData((v) {
      if (!completer.isCompleted) completer.complete(v);
    });
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

/// Spec 20: followed rides in History.
void main() {
  late AppDatabase db;
  late RideRepository repo;
  late ProviderContainer c;

  setUp(() {
    db = AppDatabase.memory();
    repo = RideRepository(RideDao(db));
    c = ProviderContainer(
      overrides: [
        rideRepositoryProvider.overrideWithValue(repo),
        dateFormatLocaleProvider.overrideWithValue('en_US'),
      ],
    );
  });
  tearDown(() async {
    c.dispose();
    await db.close();
  });

  Future<int> ride({int at = 0, int durationMs = 600000}) async {
    final id = await repo.startRide(startedAtMs: at);
    await db.rideDao.updateStats(
      id,
      distanceMetres: 4000,
      durationMs: durationMs,
      avgSpeedKmh: 15,
      maxSpeedKmh: 25,
      hasRoute: true,
    );
    return id;
  }

  Future<int> follow(
    int originalId, {
    int at = 0,
    int durationMs = 600000,
    double coverage = 1,
  }) async {
    final id = await ride(at: at, durationMs: durationMs);
    await repo.setFollowedRide(id, originalId: originalId, coverage: coverage);
    return id;
  }

  test('history entries carry their follow count', () async {
    final a = await ride();
    final f = await follow(a);
    await firstData(c, followCountsProvider);

    final items = await firstData(c, historyItemsProvider);
    final counts = {
      for (final i in items.whereType<RideEntryItem>())
        i.ride.rideId: i.followCount,
    };
    expect(counts, {a: 1, f: 0});
  });

  test('routeGroupProvider splits the group and marks the best time', () async {
    final a = await ride(at: 100, durationMs: 900000);
    final fast = await follow(a, at: 200, durationMs: 800000);
    final part = await follow(a, at: 300, durationMs: 100000, coverage: 0.4);

    final view = (await firstData(c, routeGroupProvider(a)))!;
    expect(view.group.original.rideId, a);
    expect(view.group.complete.map((r) => r.rideId), [fast]);
    expect(view.group.partial.map((r) => r.rideId), [part]);
    expect(view.group.bestRideId, fast);
    expect(view.entries[fast]!.stats.distanceMetres, 4000);
  });

  test('routeGroupProvider is null once the original is gone', () async {
    final a = await ride();
    await follow(a);
    await repo.deleteById(a);

    expect(await firstData(c, routeGroupProvider(a)), isNull);
  });

  test('followedRoutesProvider lists the followed originals', () async {
    final a = await ride(at: 100);
    await follow(a, at: 200);
    await ride(at: 300);

    final routes = await firstData(c, followedRoutesProvider);
    expect(routes.map((r) => r.original.rideId), [a]);
  });

  group('route filter', () {
    test('setRouteIds selects routes, clearing empties it', () {
      final n = c.read(historyFilterProvider.notifier);
      n.setRouteIds({1, 3});
      expect(c.read(historyFilterProvider).routeIds, {1, 3});
      n.setRouteIds(const {});
      expect(c.read(historyFilterProvider).routeIds, isEmpty);
    });

    test('keepRoutes drops selected routes that no longer exist', () {
      final n = c.read(historyFilterProvider.notifier);
      n.setRouteIds({1, 3});
      n.keepRoutes({3, 5});
      expect(c.read(historyFilterProvider).routeIds, {3});
    });

    test('reset clears the route filter', () {
      final n = c.read(historyFilterProvider.notifier);
      n.setRouteIds({1});
      n.reset();
      expect(c.read(historyFilterProvider).routeIds, isEmpty);
    });
  });
}
