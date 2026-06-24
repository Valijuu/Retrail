import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/features/home/home_providers.dart';

import 'home_test_helpers.dart';

/// Listens to an `AsyncValue` provider (driving its underlying stream) and
/// resolves with the first non-loading value. A bare `read(p.future)` doesn't
/// subscribe the Drift stream, so the future never completes — listen first.
Future<T> firstData<T>(ProviderContainer c, StreamProvider<T> p) {
  final completer = Completer<T>();
  final sub = c.listen<AsyncValue<T>>(p, (_, next) {
    next.whenData((v) {
      if (!completer.isCompleted) completer.complete(v);
    });
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

/// Direct tests for the Drift-backed home providers. These run the real
/// `repository → StreamProvider` path that the widget tests stub out — and
/// confirm the hang is widget-only: `container.read(p.future)` over a live
/// Drift `.watch()` stream resolves fine outside `testWidgets`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A Wednesday at noon — `now` for deterministic week/day/year bounds.
  final now = DateTime(2026, 6, 17, 12);
  final earlierToday = DateTime(2026, 6, 17, 8);
  final earlierThisWeek = DateTime(2026, 6, 15, 12); // Monday
  final lastMonth = DateTime(2026, 5, 1, 12);

  Future<ProviderContainer> containerWith(HomeEnv env) async {
    final c = ProviderContainer(overrides: [
      appDatabaseProvider.overrideWithValue(env.db),
      preferencesRepositoryProvider.overrideWithValue(env.prefs),
      nowMsProvider.overrideWithValue(() => now.millisecondsSinceEpoch),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  Future<int> rideAt(HomeEnv env, DateTime at,
      {Duration duration = const Duration(hours: 1)}) {
    return insertRide(env.db,
        startTime: at.millisecondsSinceEpoch,
        endTime: at.add(duration).millisecondsSinceEpoch);
  }

  test('weekly/daily/yearly providers each count only their in-range rides',
      () async {
    final env = await buildHomeEnv();
    addTearDown(env.db.close);
    await rideAt(env, earlierToday);
    await rideAt(env, earlierThisWeek);
    await rideAt(env, lastMonth);
    final c = await containerWith(env);

    expect((await firstData(c, dailyStatsProvider)).rideCount, 1);
    expect((await firstData(c, weeklyStatsProvider)).rideCount, 2);
    expect((await firstData(c, yearlyStatsProvider)).rideCount, 3);
  });

  test('recentRidesProvider returns the 2 newest by date, newest first',
      () async {
    final env = await buildHomeEnv();
    addTearDown(env.db.close);
    await rideAt(env, lastMonth);
    final mid = await rideAt(env, earlierThisWeek);
    final newest = await rideAt(env, earlierToday);
    final c = await containerWith(env);

    final recent = await firstData(c, recentRidesProvider);
    expect(recent.map((r) => r.rideId).toList(), [newest, mid]);
  });

  test('favoriteRidesProvider returns only favorites, newest hearted first',
      () async {
    final env = await buildHomeEnv();
    addTearDown(env.db.close);
    await rideAt(env, earlierToday); // not a favorite
    final favOld = await insertRide(env.db,
        startTime: earlierThisWeek.millisecondsSinceEpoch,
        favorite: true,
        favoritedAt: earlierThisWeek.millisecondsSinceEpoch);
    final favNew = await insertRide(env.db,
        startTime: lastMonth.millisecondsSinceEpoch,
        favorite: true,
        favoritedAt: now.millisecondsSinceEpoch);
    final c = await containerWith(env);

    final favorites = await firstData(c, favoriteRidesProvider);
    expect(favorites.map((r) => r.rideId).toList(), [favNew, favOld]);
  });
}
