import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/active_ride/max_speed.dart';

void main() {
  group('nextMaxSpeed', () {
    test('resets to 0 when not tracking', () {
      expect(
          nextMaxSpeed(
              current: 42, speedKmh: 30, isTracking: false, isPaused: false),
          0);
    });

    test('grows with a higher speed', () {
      expect(
          nextMaxSpeed(
              current: 10, speedKmh: 25, isTracking: true, isPaused: false),
          25);
    });

    test('never decreases', () {
      expect(
          nextMaxSpeed(
              current: 25, speedKmh: 10, isTracking: true, isPaused: false),
          25);
    });

    test('ignores updates while paused', () {
      expect(
          nextMaxSpeed(
              current: 25, speedKmh: 99, isTracking: true, isPaused: true),
          25);
    });

    test('treats null speed as 0', () {
      expect(
          nextMaxSpeed(
              current: 0, speedKmh: null, isTracking: true, isPaused: false),
          0);
    });
  });

  group('shouldNavigateHomeOnStop', () {
    test('true on external stop with no dialog open', () {
      expect(
          shouldNavigateHomeOnStop(
              rideWasActive: true, isTracking: false, anyDialogOpen: false),
          isTrue);
    });

    test('false while a dialog is open (in-app stop shows summary first)', () {
      expect(
          shouldNavigateHomeOnStop(
              rideWasActive: true, isTracking: false, anyDialogOpen: true),
          isFalse);
    });

    test('false if the ride was never active', () {
      expect(
          shouldNavigateHomeOnStop(
              rideWasActive: false, isTracking: false, anyDialogOpen: false),
          isFalse);
    });

    test('false while still tracking', () {
      expect(
          shouldNavigateHomeOnStop(
              rideWasActive: true, isTracking: true, anyDialogOpen: false),
          isFalse);
    });
  });
}
