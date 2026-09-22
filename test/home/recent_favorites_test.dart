import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:retrail/domain/distance_calculator.dart';
import 'package:retrail/features/home/home_providers.dart';

import '../domain/domain_test_helpers.dart';

void main() {
  setUpAll(() => initializeDateFormatting());
  const calc = HaversineDistanceCalculator();

  test('recent rides are the newest two by date', () {
    final list = [
      rwt(buildRide(rideId: 1, description: 'oldest', date: 100, endTime: 100), const []),
      rwt(buildRide(rideId: 2, description: 'newest', date: 300, endTime: 300), const []),
      rwt(buildRide(rideId: 3, description: 'middle', date: 200, endTime: 200), const []),
    ];
    expect(toRecentRides(list, calc).map((r) => r.title), ['newest', 'middle']);
  });

  test('unfinished rides (no endTime) never appear in recents — an active or '
      'just-discarded row must not flash into "last rides"', () {
    final list = [
      rwt(buildRide(rideId: 1, description: 'finished', date: 100, endTime: 100), const []),
      rwt(buildRide(rideId: 2, description: 'in progress', date: 300), const []),
    ];
    expect(toRecentRides(list, calc).map((r) => r.title), ['finished']);
  });

  test('favorites are isFavorite, sorted by favoritedAt desc, take 2', () {
    final list = [
      rwt(buildRide(rideId: 1, description: 'a', date: 100, isFavorite: true, favoritedAt: 10), const []),
      rwt(buildRide(rideId: 2, description: 'b', date: 200), const []),
      rwt(buildRide(rideId: 3, description: 'c', date: 50, isFavorite: true, favoritedAt: 30), const []),
      rwt(buildRide(rideId: 4, description: 'd', date: 60, isFavorite: true, favoritedAt: 20), const []),
    ];
    expect(toFavoriteRides(list, calc).map((r) => r.title), ['c', 'd']);
  });

  test(
      'an untitled ride falls back to a date formatted in the given locale, '
      'not intl\'s hardcoded English default', () {
    // Tuesday, 2 Jan 2024 — "Tuesday" (en) vs. "Dienstag" (de) make the
    // locale unmistakable regardless of which month names happen to overlap.
    final noTitle = [
      rwt(buildRide(rideId: 1, date: DateTime(2024, 1, 2).millisecondsSinceEpoch, endTime: 1), const []),
    ];
    final german = toRecentRides(noTitle, calc, locale: 'de_DE').single.title;
    final english = toRecentRides(noTitle, calc, locale: 'en_US').single.title;
    expect(german, contains('Dienstag'));
    expect(english, contains('Tuesday'));
    expect(german, isNot(contains('Tuesday')));
  });

  test('RecentRideUi reflects route presence and distance', () {
    final list = [
      rwt(buildRide(rideId: 1, description: 'with route', date: 100, endTime: 100), [
        buildTp(rideId: 1, latitude: 49.44, longitude: 11.08),
        buildTp(rideId: 1, latitude: 49.45, longitude: 11.10),
      ]),
    ];
    final ui = toRecentRides(list, calc).single;
    expect(ui.hasRoute, isTrue);
    expect(ui.startLat, 49.44);
    expect(ui.distanceKm, greaterThan(0));
  });
}
