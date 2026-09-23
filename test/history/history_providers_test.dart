import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_dao.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_items.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/settings/settings_providers.dart';

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
  group('HistoryFilterNotifier default state', () {
    test('a fresh container defaults to "All years"/unrestricted', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final f = c.read(historyFilterProvider);
      expect(f.year, isNull);
      expect(f.monthFrom, isNull);
      expect(f.monthTo, isNull);
    });

    test('reset() after picking another year/month range goes back to '
        '"All years"/unrestricted', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2020);
      notifier.setMonthFrom(1);
      notifier.setMonthTo(3);
      notifier.reset();
      final f = c.read(historyFilterProvider);
      expect(f.year, isNull);
      expect(f.monthFrom, isNull);
      expect(f.monthTo, isNull);
    });

    test('activeFilterCountProvider is 0 on a fresh container ("All years" '
        'is the baseline, not an active filter)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(activeFilterCountProvider), 0);
    });
  });

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

    test('setYear keeps a previously set month range (a month means the '
        'same thing regardless of year)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setMonthFrom(6);
      notifier.setMonthTo(8);
      notifier.setYear(2024);
      expect(c.read(historyFilterProvider).monthFrom, 6);
      expect(c.read(historyFilterProvider).monthTo, 8);
    });

    test('setYear(null) ("All years") also keeps a previously set month '
        'range — it becomes the cross-year filter', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setMonthFrom(6);
      notifier.setMonthTo(8);
      notifier.setYear(null);
      expect(c.read(historyFilterProvider).monthFrom, 6);
      expect(c.read(historyFilterProvider).monthTo, 8);
    });
  });

  group('activeFilterCountProvider with year', () {
    test('counts a set year', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(historyFilterProvider.notifier).setYear(2023);
      expect(c.read(activeFilterCountProvider), 1);
    });

    test('counts a set month range as an additional active filter', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setMonthFrom(6);
      notifier.setMonthTo(8);
      expect(c.read(activeFilterCountProvider), 2);
    });
  });

  group('HistoryFilterNotifier.setMonthFrom/setMonthTo', () {
    test('setMonthFrom sets monthFrom', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(historyFilterProvider.notifier)
        ..setYear(2023)
        ..setMonthFrom(6);
      expect(c.read(historyFilterProvider).monthFrom, 6);
    });

    test('setMonthTo sets monthTo', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      c.read(historyFilterProvider.notifier)
        ..setYear(2023)
        ..setMonthTo(8);
      expect(c.read(historyFilterProvider).monthTo, 8);
    });

    test('setMonthFrom past the current monthTo pulls monthTo up with it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setMonthTo(4);
      notifier.setMonthFrom(6);
      expect(c.read(historyFilterProvider).monthFrom, 6);
      expect(c.read(historyFilterProvider).monthTo, 6);
    });

    test('setMonthTo before the current monthFrom pulls monthFrom down with it', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      notifier.setMonthFrom(6);
      notifier.setMonthTo(4);
      expect(c.read(historyFilterProvider).monthFrom, 4);
      expect(c.read(historyFilterProvider).monthTo, 4);
    });

    test('setMonthFrom does not touch other filter fields', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setSort(SortOrder.distance);
      notifier.setYear(2023);
      notifier.setMonthFrom(6);
      expect(c.read(historyFilterProvider).sort, SortOrder.distance);
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

  group('yearPickerItemsProvider', () {
    test('unions availableHistoryYearsProvider with the selected year',
        () async {
      final currentYear = DateTime.now().year;
      final rideYear = currentYear - 2;
      final selectedYear = currentYear - 3;
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repo = RideRepository(RideDao(db));
      await repo.startRide(
          startedAtMs: DateTime(rideYear, 3, 1).millisecondsSinceEpoch);

      final c = ProviderContainer(
          overrides: [rideRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);

      // Let availableHistoryYearsProvider's stream settle first.
      await firstData(c, availableHistoryYearsProvider);
      // Selected year isn't among the DB-derived years — the defensive
      // union (e.g. its rides were just bulk-deleted) must still surface it,
      // alongside the always-included current year.
      c.read(historyFilterProvider.notifier).setYear(selectedYear);

      expect(c.read(yearPickerItemsProvider),
          [currentYear, rideYear, selectedYear]);
    });

    test('does not duplicate when the selected year is already available',
        () async {
      final currentYear = DateTime.now().year;
      final rideYear = currentYear - 1;
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repo = RideRepository(RideDao(db));
      await repo.startRide(
          startedAtMs: DateTime(rideYear, 3, 1).millisecondsSinceEpoch);

      final c = ProviderContainer(
          overrides: [rideRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);

      await firstData(c, availableHistoryYearsProvider);
      c.read(historyFilterProvider.notifier).setYear(rideYear);

      expect(c.read(yearPickerItemsProvider), [currentYear, rideYear]);
    });

    test('always includes the current calendar year, even with no rides yet',
        () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repo = RideRepository(RideDao(db));
      // No rides inserted at all — the year the app just rolled into must
      // still be selectable without waiting for a first ride in it.

      final c = ProviderContainer(
          overrides: [rideRepositoryProvider.overrideWithValue(repo)]);
      addTearDown(c.dispose);

      await firstData(c, availableHistoryYearsProvider);

      expect(c.read(yearPickerItemsProvider), [DateTime.now().year]);
    });
  });

  group('historyItemsProvider wired to effectiveRange', () {
    // The one integration seam in the branch with no direct test:
    // `effectiveRange` (unit-tested) and `RideDao.getRidesInRange`
    // (unit-tested) are correctly connected through `historyItemsProvider`
    // when a year filter is set.
    test('setYear(2023) restricts results to rides dated in 2023 only',
        () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final repo = RideRepository(RideDao(db));
      final id2023 = await repo.startRide(
          startedAtMs: DateTime(2023, 6, 1).millisecondsSinceEpoch);
      final id2024 = await repo.startRide(
          startedAtMs: DateTime(2024, 6, 1).millisecondsSinceEpoch);

      final c = ProviderContainer(overrides: [
        rideRepositoryProvider.overrideWithValue(repo),
        // Avoid pulling in the real preferences/locale chain — this test
        // only cares about which rides the range query returns.
        dateFormatLocaleProvider.overrideWithValue('en_US'),
      ]);
      addTearDown(c.dispose);

      final notifier = c.read(historyFilterProvider.notifier);
      notifier.setYear(2023);
      // The default month range (the real current calendar month, whatever
      // that happens to be at test-run time) would otherwise filter out this
      // June-dated fixture ride on months that aren't June — widen to the
      // full year, since this test is about the year restriction only.
      notifier.setMonthFrom(1);
      notifier.setMonthTo(12);

      final items = await firstData(c, historyItemsProvider);
      final rideIds = items
          .whereType<RideEntryItem>()
          .map((e) => e.ride.rideId)
          .toList();

      expect(rideIds, [id2023]);
      expect(rideIds, isNot(contains(id2024)));
    });
  });
}
