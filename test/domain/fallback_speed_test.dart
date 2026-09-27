import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/fallback_speed.dart';

double? _speed(double distanceMetres,
        {double elapsedSeconds = 1, double accuracyA = 5, double accuracyB = 5}) =>
    fallbackSpeedKmh(
      distanceMetres: distanceMetres,
      elapsedSeconds: elapsedSeconds,
      accuracyA: accuracyA,
      accuracyB: accuracyB,
      maxAccuracyM: 35,
      maxSpeedMs: 50,
    );

void main() {
  group('fallbackSpeedKmh', () {
    test('real movement: 10 m in 1 s, accuracy 5/5 → 36 km/h', () {
      expect(_speed(10), closeTo(36, 1e-9));
    });
    test('no time passed (0 s) → null', () {
      expect(_speed(10, elapsedSeconds: 0), isNull);
    });
    test('negative elapsed time → null', () {
      expect(_speed(10, elapsedSeconds: -1), isNull);
    });
    test('first fix too vague (accuracy 36 > 35) → null', () {
      expect(_speed(40, accuracyA: 36), isNull);
    });
    test('second fix too vague (accuracy 36 > 35) → null', () {
      expect(_speed(40, accuracyB: 36), isNull);
    });
    test('4 m within 5 m accuracy (GPS noise) → 0 km/h', () {
      expect(_speed(4), 0.0);
    });
    test('5 m equal to the larger accuracy (3 / 5) → 0 km/h', () {
      expect(_speed(5, accuracyA: 3, accuracyB: 5), 0.0);
    });
    test('impossible jump: 100 m in 1 s (> 50 m/s) → null', () {
      expect(_speed(100), isNull);
    });
    test('exactly the limit: 50 m in 1 s → 180 km/h', () {
      expect(_speed(50), closeTo(180, 1e-9));
    });
    test('reported iOS spike: 194 m in 1 s at accuracy 65 → null, not ~699 km/h',
        () {
      expect(_speed(194, accuracyA: 65, accuracyB: 65), isNull);
    });
  });
}
