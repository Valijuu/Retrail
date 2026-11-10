import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/domain/ride_outline.dart';
import 'package:retrail/features/history/outline_cache.dart';

RideOutlineRow _row(int id, [List<(double, double)>? pts]) {
  final outline = RideOutline([
    for (final p in pts ?? [(48.0, 11.0), (48.001, 11.001)])
      (lat: p.$1, lng: p.$2),
  ]);
  final box = outline.bounds!;
  return RideOutlineRow(
    rideId: id,
    polyline: outline.encode(),
    south: box.south,
    west: box.west,
    north: box.north,
    east: box.east,
  );
}

void main() {
  late OutlineCache cache;
  setUp(() => cache = OutlineCache());

  test('an unknown ride has no entry', () {
    expect(cache[1], isNull);
    expect(cache.rideIds, isEmpty);
  });

  test('adding rows makes them available by ride id', () {
    cache.addRows([_row(1), _row(2)]);
    expect(cache.rideIds, unorderedEquals([1, 2]));
    expect(cache[1]!.bounds.south, 48.0);
  });

  test('the outline decodes on first use and then stays decoded', () {
    cache.addRows([_row(1)]);
    final entry = cache[1]!;
    expect(entry.isDecoded, isFalse);
    expect(entry.outline.points, hasLength(2));
    expect(entry.isDecoded, isTrue);
    expect(identical(entry.outline, entry.outline), isTrue);
  });

  test('syncing ids reports what is missing and drops what is gone', () {
    cache.addRows([_row(1), _row(2)]);
    final missing = cache.sync({2, 3});
    expect(missing, {3});
    expect(cache.rideIds, [2]);
  });

  test('evict drops the outline and its fragments', () {
    cache.addRows([_row(1)]);
    cache[1]!.heatFragment = 'x';
    cache.evict(1);
    expect(cache[1], isNull);
  });

  test('adding a row for a cached ride keeps the entry and its fragments', () {
    cache.addRows([_row(1)]);
    cache[1]!.lineFragment = 'kept';
    cache.addRows([_row(1)]);
    expect(cache[1]!.lineFragment, 'kept');
  });

  test('a changed row for a cached ride replaces the entry', () {
    cache.addRows([_row(1)]);
    cache[1]!.lineFragment = 'old';
    cache.addRows([
      _row(1, [(1.0, 2.0), (1.1, 2.1)]),
    ]);
    expect(cache[1]!.lineFragment, isNull);
    expect(cache[1]!.bounds.south, 1.0);
  });

  test('an empty polyline is marked as having no outline', () {
    cache.addRows([
      const RideOutlineRow(
        rideId: 5,
        polyline: '',
        south: 0,
        west: 0,
        north: 0,
        east: 0,
      ),
    ]);
    expect(cache[5]!.isEmpty, isTrue);
  });
}
