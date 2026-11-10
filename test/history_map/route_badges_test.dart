import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/features/history_map/route_badges.dart';

Ride _ride(
  int id, {
  int? followed,
  int durationMs = 1000,
  double? coverage,
  int date = 0,
}) => Ride(
  rideId: id,
  isFavorite: false,
  hasRoute: true,
  date: date,
  startTime: date,
  durationMs: durationMs,
  distanceMetres: 100,
  avgSpeedKmh: 10,
  maxSpeedKmh: 20,
  followedRideId: followed,
  followCoverage: coverage,
);

void main() {
  test('rides outside any group have no badge and no group size', () {
    final badges = routeBadges([_ride(1), _ride(2)]);
    expect(badges.bestRideIds, isEmpty);
    expect(badges.groupSizeOf(1), 1);
  });

  test('the fastest complete ride of a group is its best', () {
    final badges = routeBadges([
      _ride(1, durationMs: 900),
      _ride(2, followed: 1, durationMs: 800, coverage: 1, date: 2),
      _ride(3, followed: 1, durationMs: 700, coverage: 0.3, date: 3),
    ]);
    expect(badges.bestRideIds, {2});
    expect(badges.groupSizeOf(1), 3);
    expect(badges.groupSizeOf(3), 3);
  });

  test('deleting the best ride recomputes the best without it', () {
    final rides = [
      _ride(1, durationMs: 900),
      _ride(2, followed: 1, durationMs: 800, coverage: 1, date: 2),
    ];
    expect(routeBadges(rides).bestRideIds, {2});
    expect(routeBadges([rides.first]).bestRideIds, isEmpty);
  });

  test('follows of a deleted original are ordinary rides', () {
    final badges = routeBadges([
      _ride(2, followed: null, durationMs: 800),
      _ride(3, followed: null, durationMs: 700),
    ]);
    expect(badges.bestRideIds, isEmpty);
    expect(badges.groupSizeOf(2), 1);
  });

  test('a ride that follows a missing original counts as alone', () {
    final badges = routeBadges([_ride(2, followed: 99, coverage: 1)]);
    expect(badges.groupSizeOf(2), 1);
    expect(badges.bestRideIds, isEmpty);
  });
}
