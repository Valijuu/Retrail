import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/distance_calculator.dart';

void main() {
  const calc = HaversineDistanceCalculator();

  test('identical points have zero distance', () {
    expect(calc.distanceBetween(52.5, 13.4, 52.5, 13.4), 0.0);
  });

  test('one degree of latitude is about 111 km', () {
    expect(calc.distanceBetween(0, 0, 1, 0), closeTo(111195, 100));
  });

  test('distance is symmetric', () {
    final ab = calc.distanceBetween(52.5, 13.4, 48.1, 11.6);
    final ba = calc.distanceBetween(48.1, 11.6, 52.5, 13.4);
    expect(ab, closeTo(ba, 1e-6));
    expect(ab, greaterThan(0));
  });
}
