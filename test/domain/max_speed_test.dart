import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/max_speed.dart';

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
}
