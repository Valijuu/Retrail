import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_providers.dart';

/// Listens to an `AsyncValue` provider (driving its underlying stream) and
/// resolves with the first non-loading value. A bare `read(p.future)` doesn't
/// subscribe the Drift stream, so the future never completes — listen first
/// (same pattern as `test/home/home_providers_test.dart`).
Future<T> firstData<T>(ProviderContainer c, StreamProvider<T> p) {
  final completer = Completer<T>();
  final sub = c.listen<AsyncValue<T>>(p, (_, next) {
    next.whenData((v) {
      if (!completer.isCompleted) completer.complete(v);
    });
  }, fireImmediately: true);
  return completer.future.whenComplete(sub.close);
}

void main() {
  group('HistoryFilterNotifier.setYear', () {
    test('sets the year', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(historyFilterProvider.notifier).setYear(2023);
      expect(c.read(historyFilterProvider).year, 2023);
    });

    test('setYear(null) resets back to "All years"', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setYear(null);
      expect(c.read(historyFilterProvider).year, isNull);
    });

    test('setYear does not touch other filter fields', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setSort(SortOrder.distance);
      notifier.setYear(2023);
      expect(c.read(historyFilterProvider).sort, SortOrder.distance);
    });
  });

  group('activeFilterCountProvider with year', () {
    test('counts a set year', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(historyFilterProvider.notifier).setYear(2023);
      expect(c.read(activeFilterCountProvider), 1);
    });
  });

  group('availableHistoryYearsProvider', () {
    test('extracts distinct years from ride.date, sorted descending',
        () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repo = RideRepository(RideDao(db));
      await repo.startRide(
          startedAtMs: DateTime(2022, 6, 1).millisecondsSinceEpoch);
      await repo.startRide(
          startedAtMs: DateTime(2024, 3, 1).millisecondsSinceEpoch);
      await repo.startRide(
          startedAtMs: DateTime(2024, 8, 1).millisecondsSinceEpoch);

      final c = ProviderContainer(
          overrides: [rideRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);

      final years = await firstData(c, availableHistoryYearsProvider);
      expect(years, [2024, 2022]);
    });

    test('falls back to startTime when date is null', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final dao = RideDao(db);
      final repo = RideRepository(dao);
      // Ride with a startTime but no date (date defaults to startedAtMs in
      // startRide, so insert directly to exercise the fallback).
      await dao.insert(RidesCompanion.insert(
        startTime: const drift.Value(
            1700000000000), // 2023-11-14, arbitrary fixed epoch ms
        date: const drift.Value.absent(),
      ));

      final c = ProviderContainer(
          overrides: [rideRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);

      final years = await firstData(c, availableHistoryYearsProvider);
      expect(years, [2023]);
    });
  });
}
