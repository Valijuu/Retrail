import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/active_ride/navigation_rules.dart';

void main() {
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
