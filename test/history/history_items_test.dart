import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_with_trackpoints.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_items.dart';

const _calc = HaversineDistanceCalculator();

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
    );

Trackpoint _tp(int rideId, double lat, double lng, {double? speed}) => Trackpoint(
      trackpointId: 0,
      rideId: rideId,
      latitude: lat,
      longitude: lng,
      timestamp: 0,
      speed: speed,
    );

RideWithTrackpoints _rwt(Ride r, [List<Trackpoint> tps = const []]) =>
    RideWithTrackpoints(ride: r, trackpoints: tps);

List<HistoryItem> _build(List<RideWithTrackpoints> rides, HistoryFilter f) =>
    buildHistoryItems(rides, f, calc: _calc, nowMs: _now);

List<int> _rideIds(List<HistoryItem> items) => [
      for (final i in items)
        if (i is RideEntryItem) i.rwt.ride.rideId,
    ];

void main() {
  group('filtering', () {
    test('favorites-only keeps only favorites', () {
      final items = _build([
        _rwt(_ride(1, fav: true)),
        _rwt(_ride(2, fav: false)),
      ], const HistoryFilter(favoritesOnly: true));
      expect(_rideIds(items), [1]);
    });

    test('activity type filters by Ride.typ', () {
      final items = _build([
        _rwt(_ride(1, typ: 'SCOOTER')),
        _rwt(_ride(2, typ: 'LONGBOARD')),
      ], const HistoryFilter(activities: {ActivityType.scooter}));
      expect(_rideIds(items), [1]);
    });

    test('multiple activities combine as any-of', () {
      final items = _build([
        _rwt(_ride(1, typ: 'SCOOTER')),
        _rwt(_ride(2, typ: 'LONGBOARD')),
        _rwt(_ride(3, typ: 'SKATEBOARD')),
      ], const HistoryFilter(
          activities: {ActivityType.scooter, ActivityType.longboard}));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('search matches title or comment, case-insensitive', () {
      final items = _build([
        _rwt(_ride(1, desc: 'Sunset Cruise')),
        _rwt(_ride(2, comment: 'great PACE today')),
        _rwt(_ride(3, desc: 'Morning')),
      ], const HistoryFilter(query: 'pace'));
      expect(_rideIds(items), unorderedEquals([2]));

      final items2 = _build([
        _rwt(_ride(1, desc: 'Sunset Cruise')),
      ], const HistoryFilter(query: '  sunset '));
      expect(_rideIds(items2), [1]);
    });
  });

  group('filtering by month range (cross-year — see monthOfYearInRange)', () {
    test('monthFrom/monthTo restrict rides to that calendar month, any year', () {
      final items = _build([
        _rwt(_ride(1, date: DateTime(2019, 3, 10).millisecondsSinceEpoch)),
        _rwt(_ride(2, date: DateTime(2024, 5, 20).millisecondsSinceEpoch)),
        _rwt(_ride(3, date: DateTime(2024, 6, 1).millisecondsSinceEpoch)),
        _rwt(_ride(4, date: DateTime(2031, 2, 28).millisecondsSinceEpoch)),
      ], const HistoryFilter(monthFrom: 3, monthTo: 5));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('only monthFrom set → monthTo defaults to December', () {
      final items = _build([
        _rwt(_ride(1, date: DateTime(2020, 4, 1).millisecondsSinceEpoch)),
        _rwt(_ride(2, date: DateTime(2020, 12, 31).millisecondsSinceEpoch)),
        _rwt(_ride(3, date: DateTime(2020, 2, 1).millisecondsSinceEpoch)),
      ], const HistoryFilter(monthFrom: 3));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('only monthTo set → monthFrom defaults to January', () {
      final items = _build([
        _rwt(_ride(1, date: DateTime(2020, 1, 1).millisecondsSinceEpoch)),
        _rwt(_ride(2, date: DateTime(2020, 5, 1).millisecondsSinceEpoch)),
        _rwt(_ride(3, date: DateTime(2020, 9, 1).millisecondsSinceEpoch)),
      ], const HistoryFilter(monthTo: 5));
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('no month range set does not filter at all', () {
      final items = _build([
        _rwt(_ride(1, date: DateTime(2019, 1, 1).millisecondsSinceEpoch)),
        _rwt(_ride(2, date: DateTime(2031, 12, 31).millisecondsSinceEpoch)),
      ], const HistoryFilter());
      expect(_rideIds(items), unorderedEquals([1, 2]));
    });

    test('a ride with neither date nor startTime is excluded once a month '
        'range is active', () {
      final noTimestamp = RideWithTrackpoints(
        ride: Ride(
          rideId: 5,
          description: null,
          typ: null,
          startTime: null,
          endTime: null,
          date: null,
          comment: null,
          isFavorite: false,
          favoritedAt: null,
        ),
        trackpoints: const [],
      );
      final items = _build([
        noTimestamp,
        _rwt(_ride(1, date: DateTime(2020, 4, 1).millisecondsSinceEpoch)),
      ], const HistoryFilter(monthFrom: 3, monthTo: 5));
      expect(_rideIds(items), [1]);
    });
  });

  group('sorting', () {
    test('distance descending', () {
      final long = _rwt(_ride(1), [_tp(1, 52.0, 13.0), _tp(1, 52.01, 13.0)]);
      final short = _rwt(_ride(2), [_tp(2, 52.0, 13.0), _tp(2, 52.001, 13.0)]);
      final items =
          _build([short, long], const HistoryFilter(sort: SortOrder.distance));
      expect(_rideIds(items), [1, 2]);
    });

    test('speed descending uses max trackpoint speed', () {
      final fast = _rwt(_ride(1), [_tp(1, 52.0, 13.0, speed: 10)]);
      final slow = _rwt(_ride(2), [_tp(2, 52.0, 13.0, speed: 3)]);
      final items =
          _build([slow, fast], const HistoryFilter(sort: SortOrder.speed));
      expect(_rideIds(items), [1, 2]);
    });

    test('duration ascending (shortest first)', () {
      final longRide = _rwt(_ride(1, start: 0, end: 100000));
      final shortRide = _rwt(_ride(2, start: 0, end: 10000));
      final items = _build(
          [longRide, shortRide], const HistoryFilter(sort: SortOrder.duration));
      expect(_rideIds(items), [2, 1]);
    });
  });

  group('date grouping', () {
    test('inserts headers, days descending, rides within a day descending', () {
      final today1 = _rwt(_ride(1, date: _now));
      final today2 = _rwt(_ride(2, date: _now + 3600000));
      final yest = _rwt(_ride(3, date: _now - _day));
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
      final items = _build([_rwt(_ride(1, date: _now))], const HistoryFilter());
      // items = [header, ride 1]
      expect(estimatedOffsetOf(items, 1, headerExtent: 30, cardExtent: 240), 30);
    });

    test('sums headers and cards up to a deep target', () {
      final items = _build([
        _rwt(_ride(1, date: _now)),
        _rwt(_ride(2, date: _now - _day)),
        _rwt(_ride(3, date: _now - 2 * _day)),
      ], const HistoryFilter());
      // [h, 1, h, 2, h, 3] → offset of 3 = 2 headers + 2 cards + 1 header.
      expect(estimatedOffsetOf(items, 3, headerExtent: 30, cardExtent: 240),
          3 * 30 + 2 * 240);
    });

    test('unknown ride id yields 0 (top of list)', () {
      final items = _build([_rwt(_ride(1, date: _now))], const HistoryFilter());
      expect(estimatedOffsetOf(items, 99), 0);
    });
  });

  group('filter badges', () {
    test('activeFilterCount excludes the search query', () {
      // year and month range both match _now's year/month (the app default,
      // see HistoryFilterNotifier) so neither adds to the count — isolates
      // the 3 other active sections.
      const f = HistoryFilter(
        year: 2024,
        monthFrom: 6,
        monthTo: 6,
        sort: SortOrder.distance,
        favoritesOnly: true,
        activities: {ActivityType.scooter},
        query: 'x',
      );
      expect(activeFilterCount(f, nowMs: _now), 3);
    });

    test('isFilterActive includes the search query', () {
      expect(isFilterActive(const HistoryFilter(query: 'x')), isTrue);
      expect(
          isFilterActive(
              const HistoryFilter(year: 2024, monthFrom: 6, monthTo: 6),
              nowMs: _now),
          isFalse);
    });
  });
}
