import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_items.dart';

// 2024-06-12 12:00 local-ish (fixed reference for date-grouping/badge tests).
const _now = 1718193600000;
const _day = 86400000;

Ride _ride(
  int id, {
  int? date,
  String? typ,
  bool fav = false,
  String? desc,
  String? comment,
  int? start,
  int? end,
  double? distanceMetres,
  int? durationMs,
  double? avgSpeedKmh,
  double? maxSpeedKmh,
  bool hasRoute = false,
}) =>
    Ride(
      rideId: id,
      description: desc,
      typ: typ,
      startTime: start,
      endTime: end,
      date: date ?? _now,
      comment: comment,
      isFavorite: fav,
      favoritedAt: fav ? date : null,
      distanceMetres: distanceMetres,
      durationMs: durationMs,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      hasRoute: hasRoute,
    );

List<HistoryItem> _build(List<Ride> rides, HistoryFilter f) =>
    buildHistoryItems(rides, f, nowMs: _now);

List<int> _rideIds(List<HistoryItem> items) => [
      for (final i in items)
        if (i is RideEntryItem) i.ride.rideId,
    ];

void main() {
  group('filtering', () {
    test('favorites-only keeps only favorites', () {
      final items = _build([
        _ride(1, fav: true),
        _ride(2, fav: false),
      ], const HistoryFilter(favoritesOnly: true));
      expect(_rideIds(items), [1]);
    });

    test('activity type filters by Ride.typ', () {
      final items = _build([
        _ride(1, typ: 'SCOOTER'),
        _ride(2, typ: 'LONGBOARD'),
      ], const HistoryFilter(activities: {ActivityType.scooter}));
      expect(_rideIds(items), [1]);
    });

    test('multiple activities combine as any-of', () {
      final items = _build([
        _ride(1, typ: 'SCOOTER'),
        _ride(2, typ: 'LONGBOARD'),
        _ride(3, typ: 'SKATEBOARD'),
      ], const HistoryFilter(
          activities: {ActivityType.scooter, ActivityType.longboard}));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('search matches title or comment, case-insensitive', () {
      final items = _build([
        _ride(1, desc: 'Sunset Cruise'),
        _ride(2, comment: 'great PACE today'),
        _ride(3, desc: 'Morning'),
      ], const HistoryFilter(query: 'pace'));
      expect(_rideIds(items), unorderedEquals([2]));

      final items2 = _build([
        _ride(1, desc: 'Sunset Cruise'),
      ], const HistoryFilter(query: '  sunset '));
      expect(_rideIds(items2), [1]);
    });
  });

  group('filtering by month range (cross-year — see monthOfYearInRange)', () {
    test('monthFrom/monthTo restrict rides to that calendar month, any year', () {
      final items = _build([
        _ride(1, date: DateTime(2019, 3, 10).millisecondsSinceEpoch),
        _ride(2, date: DateTime(2024, 5, 20).millisecondsSinceEpoch),
        _ride(3, date: DateTime(2024, 6, 1).millisecondsSinceEpoch),
        _ride(4, date: DateTime(2031, 2, 28).millisecondsSinceEpoch),
      ], const HistoryFilter(monthFrom: 3, monthTo: 5));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('only monthFrom set → monthTo defaults to December', () {
      final items = _build([
        _ride(1, date: DateTime(2020, 4, 1).millisecondsSinceEpoch),
        _ride(2, date: DateTime(2020, 12, 31).millisecondsSinceEpoch),
        _ride(3, date: DateTime(2020, 2, 1).millisecondsSinceEpoch),
      ], const HistoryFilter(monthFrom: 3));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('only monthTo set → monthFrom defaults to January', () {
      final items = _build([
        _ride(1, date: DateTime(2020, 1, 1).millisecondsSinceEpoch),
        _ride(2, date: DateTime(2020, 5, 1).millisecondsSinceEpoch),
        _ride(3, date: DateTime(2020, 9, 1).millisecondsSinceEpoch),
      ], const HistoryFilter(monthTo: 5));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('no month range set does not filter at all', () {
      final items = _build([
        _ride(1, date: DateTime(2019, 1, 1).millisecondsSinceEpoch),
        _ride(2, date: DateTime(2031, 12, 31).millisecondsSinceEpoch),
      ], const HistoryFilter());
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('a ride with neither date nor startTime is excluded once a month '
        'range is active', () {
      const noTimestamp = Ride(
        rideId: 5,
        description: null,
        typ: null,
        startTime: null,
        endTime: null,
        date: null,
        comment: null,
        isFavorite: false,
        favoritedAt: null,
        hasRoute: false,
      );
      final items = _build([
        noTimestamp,
        _ride(1, date: DateTime(2020, 4, 1).millisecondsSinceEpoch),
      ], const HistoryFilter(monthFrom: 3, monthTo: 5));
      expect(_rideIds(items), [1]);
    });
  });

  group('sorting', () {
    test('distance descending (denormalized distanceMetres)', () {
      final long = _ride(1, start: 0, end: 1000, distanceMetres: 500,
          durationMs: 1000, avgSpeedKmh: 1, maxSpeedKmh: 1);
      final short = _ride(2, start: 0, end: 1000, distanceMetres: 50,
          durationMs: 1000, avgSpeedKmh: 1, maxSpeedKmh: 1);
      final items =
          _build([short, long], const HistoryFilter(sort: SortOrder.distance));
      expect(_rideIds(items), [1, 2]);
    });

    test('speed descending (denormalized maxSpeedKmh)', () {
      final fast = _ride(1, start: 0, end: 1000, distanceMetres: 1,
          durationMs: 1000, avgSpeedKmh: 1, maxSpeedKmh: 36);
      final slow = _ride(2, start: 0, end: 1000, distanceMetres: 1,
          durationMs: 1000, avgSpeedKmh: 1, maxSpeedKmh: 10.8);
      final items =
          _build([slow, fast], const HistoryFilter(sort: SortOrder.speed));
      expect(_rideIds(items), [1, 2]);
    });

    test('duration ascending (shortest first)', () {
      final longRide = _ride(1, start: 0, end: 100000);
      final shortRide = _ride(2, start: 0, end: 10000);
      final items = _build(
          [longRide, shortRide], const HistoryFilter(sort: SortOrder.duration));
      expect(_rideIds(items), [2, 1]);
    });
  });

  group('stats source', () {
    test('uses the denormalized stats on the ride row when present', () {
      final ride = _ride(1,
          start: 0,
          end: 5000,
          distanceMetres: 123.4,
          durationMs: 5000,
          avgSpeedKmh: 8.8,
          maxSpeedKmh: 20.0);
      final items = _build([ride], const HistoryFilter());
      final stats = items.whereType<RideEntryItem>().single.stats;
      expect(stats.distanceMetres, 123.4);
      expect(stats.maxSpeedKmh, 20.0);
    });

    test('falls back to a duration-only estimate when the row has no '
        'stored stats (no trackpoints on hand to recompute from — see '
        'issue #21)', () {
      final ride = _ride(1, start: 0, end: 3600000);
      final items = _build([ride], const HistoryFilter());
      final stats = items.whereType<RideEntryItem>().single.stats;
      expect(stats.durationMs, 3600000);
      expect(stats.distanceMetres, 0);
    });
  });

  group('date grouping', () {
    test('inserts headers, days descending, rides within a day descending', () {
      final today1 = _ride(1, date: _now);
      final today2 = _ride(2, date: _now + 3600000);
      final yest = _ride(3, date: _now - _day);
      final items = _build(
          [today1, yest, today2], const HistoryFilter(sort: SortOrder.date));

      // First item is today's header, then ride 2 (later) before ride 1.
      expect(items.first, isA<DateHeaderItem>());
      expect((items.first as DateHeaderItem).dayKey, formatRideDayKey(_now));
      expect(_rideIds(items), [2, 1, 3]);
      // Two day headers: today then yesterday.
      final keys = [
        for (final i in items)
          if (i is DateHeaderItem) i.dayKey
      ];
      expect(keys, [formatRideDayKey(_now), formatRideDayKey(_now - _day)]);
    });
  });

  group('estimatedOffsetOf', () {
    test('first card after the first header is one header down', () {
      final items = _build([_ride(1, date: _now)], const HistoryFilter());
      // items = [header, ride 1]
      expect(estimatedOffsetOf(items, 1, headerExtent: 30, cardExtent: 240), 30);
    });

    test('sums headers and cards up to a deep target', () {
      final items = _build([
        _ride(1, date: _now),
        _ride(2, date: _now - _day),
        _ride(3, date: _now - 2 * _day),
      ], const HistoryFilter());
      // [h, 1, h, 2, h, 3] → offset of 3 = 2 headers + 2 cards + 1 header.
      expect(estimatedOffsetOf(items, 3, headerExtent: 30, cardExtent: 240),
          3 * 30 + 2 * 240);
    });

    test('unknown ride id yields 0 (top of list)', () {
      final items = _build([_ride(1, date: _now)], const HistoryFilter());
      expect(estimatedOffsetOf(items, 99), 0);
    });
  });

  group('filter badges', () {
    test('activeFilterCount excludes the search query', () {
      const f = HistoryFilter(
        year: 2024,
        monthFrom: 6,
        monthTo: 6,
        sort: SortOrder.distance,
        favoritesOnly: true,
        activities: {ActivityType.scooter},
        query: 'x',
      );
      // year + month range + sort + favorites + activities = 5; query is
      // excluded (it has its own visible bar).
      expect(activeFilterCount(f), 5);
    });
  });
}
