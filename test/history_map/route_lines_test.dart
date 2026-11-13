import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/history_map/route_badges.dart';
import 'package:retrail/features/history_map/route_lines.dart';

void main() {
  test('a matched ride takes its line key, the group size counts the line', () {
    final lines = {1: 1, 2: 1, 3: 3};
    expect(routeKeyOf(2, lines, null), 1);
    expect(routeSizeOf(2, lines, null), 2);
    expect(routeSizeOf(3, lines, null), 1);
  });

  test('before the lines are matched the follow groups stand in', () {
    const badges = RouteBadges({}, {5: 3, 6: 3}, {5: 5, 6: 5});
    expect(routeKeyOf(6, null, badges), 5);
    expect(routeSizeOf(6, null, badges), 3);
  });

  test('a ride in neither is a route of its own', () {
    expect(routeKeyOf(9, null, null), 9);
    expect(routeSizeOf(9, null, null), 1);
    expect(routeKeyOf(9, const {}, null), 9);
  });
}
