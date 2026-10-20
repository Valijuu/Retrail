import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/followed_route.dart';
import 'package:retrail/domain/route_selection.dart';

// Wednesday, June 12, 2024.
const _june12 = 1718193600000;

FollowedRoute _route(int id, [String? title]) => FollowedRoute(
  original: Ride(
    rideId: id,
    description: title,
    date: _june12,
    isFavorite: false,
    hasRoute: true,
  ),
  rideCount: 2,
  lastRiddenMs: _june12,
);

final _routes = [_route(1, 'Hausrunde'), _route(2, 'Rheinufer'), _route(3)];

List<int> _ids(List<FollowedRoute> routes) => [
  for (final r in routes) r.original.rideId,
];

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  group('searchRoutes', () {
    test('an empty query keeps every route in its order', () {
      expect(_ids(searchRoutes(_routes, '', locale: 'en')), [1, 2, 3]);
    });
    test('matches the title case-insensitively — "haus" finds "Hausrunde"', () {
      expect(_ids(searchRoutes(_routes, 'haus', locale: 'en')), [1]);
    });
    test('surrounding spaces are ignored — "  rhein " finds "Rheinufer"', () {
      expect(_ids(searchRoutes(_routes, '  rhein ', locale: 'en')), [2]);
    });
    test('an untitled route is found by its date title — "june" finds it', () {
      expect(_ids(searchRoutes(_routes, 'june', locale: 'en')), [3]);
    });
    test('no match gives an empty list', () {
      expect(searchRoutes(_routes, 'xyz', locale: 'en'), isEmpty);
    });
  });

  group('selectedRouteTitles', () {
    test('nothing selected is all routes — empty list', () {
      expect(selectedRouteTitles(_routes, const {}, locale: 'en'), isEmpty);
    });
    test('one selected route gives its title', () {
      expect(selectedRouteTitles(_routes, const {2}, locale: 'en'), [
        'Rheinufer',
      ]);
    });
    test('two selected routes give both titles in list order', () {
      expect(selectedRouteTitles(_routes, const {2, 1}, locale: 'en'), [
        'Hausrunde',
        'Rheinufer',
      ]);
    });
    test('ids no longer among the routes are left out', () {
      expect(selectedRouteTitles(_routes, const {1, 9}, locale: 'en'), [
        'Hausrunde',
      ]);
    });
  });
}
