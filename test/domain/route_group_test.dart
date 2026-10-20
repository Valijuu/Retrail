import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/route_group.dart';

RouteGroupRide _ride(
  int id, {
  int at = 0,
  int durationMs = 600000,
  double? coverage,
}) => RouteGroupRide(
  rideId: id,
  timestampMs: at,
  durationMs: durationMs,
  coverage: coverage,
);

void main() {
  group('buildRouteGroup', () {
    test(
      'an original without follows has no complete, no partial, no best',
      () {
        final g = buildRouteGroup(_ride(1), const []);
        expect(g.original.rideId, 1);
        expect(g.complete, isEmpty);
        expect(g.partial, isEmpty);
        expect(g.bestRideId, isNull);
      },
    );
    test('a follow covering 95 % is complete', () {
      final g = buildRouteGroup(_ride(1), [_ride(2, coverage: 0.95)]);
      expect([for (final r in g.complete) r.rideId], [2]);
      expect(g.partial, isEmpty);
    });
    test('a follow covering 50 % is partial', () {
      final g = buildRouteGroup(_ride(1), [_ride(2, coverage: 0.5)]);
      expect(g.complete, isEmpty);
      expect([for (final r in g.partial) r.rideId], [2]);
    });
    test('exactly 90 % is complete — the threshold is inclusive', () {
      final g = buildRouteGroup(_ride(1), [_ride(2, coverage: 0.9)]);
      expect([for (final r in g.complete) r.rideId], [2]);
    });
    test('a follow without a coverage is partial', () {
      final g = buildRouteGroup(_ride(1), [_ride(2)]);
      expect([for (final r in g.partial) r.rideId], [2]);
    });
    test('complete and partial follows are listed oldest first', () {
      final g = buildRouteGroup(_ride(1), [
        _ride(2, at: 300, coverage: 1),
        _ride(3, at: 100, coverage: 1),
        _ride(4, at: 250, coverage: 0.2),
        _ride(5, at: 50, coverage: 0.2),
      ]);
      expect([for (final r in g.complete) r.rideId], [3, 2]);
      expect([for (final r in g.partial) r.rideId], [5, 4]);
    });
    test('one candidate alone gets no best — original only plus a partial', () {
      final g = buildRouteGroup(_ride(1), [
        _ride(2, durationMs: 1000, coverage: 0.3),
      ]);
      expect(g.bestRideId, isNull);
    });
    test(
      'the faster complete follow beats the original — best is the follow',
      () {
        final g = buildRouteGroup(_ride(1, durationMs: 900000), [
          _ride(2, at: 1, durationMs: 800000, coverage: 1),
          _ride(3, at: 2, durationMs: 850000, coverage: 1),
        ]);
        expect(g.bestRideId, 2);
      },
    );
    test(
      'the original can be the best — it is faster than every complete follow',
      () {
        final g = buildRouteGroup(_ride(1, durationMs: 700000), [
          _ride(2, at: 1, durationMs: 800000, coverage: 1),
        ]);
        expect(g.bestRideId, 1);
      },
    );
    test('a faster partial follow never wins the best', () {
      final g = buildRouteGroup(_ride(1, durationMs: 900000), [
        _ride(2, at: 1, durationMs: 800000, coverage: 1),
        _ride(3, at: 2, durationMs: 100000, coverage: 0.4),
      ]);
      expect(g.bestRideId, 2);
    });
    test('a ride without a duration (0 ms) never wins the best', () {
      final g = buildRouteGroup(_ride(1, durationMs: 900000), [
        _ride(2, at: 1, durationMs: 0, coverage: 1),
        _ride(3, at: 2, durationMs: 800000, coverage: 1),
      ]);
      expect(g.bestRideId, 3);
    });
    test('equal durations — the older ride keeps the best', () {
      final g = buildRouteGroup(_ride(1, durationMs: 900000), [
        _ride(2, at: 1, durationMs: 800000, coverage: 1),
        _ride(3, at: 2, durationMs: 800000, coverage: 1),
      ]);
      expect(g.bestRideId, 2);
    });
  });
}
