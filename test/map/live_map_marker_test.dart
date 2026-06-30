import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('rideMarkerIsBadge', () {
    test('null and OTHER use the plain dot', () {
      expect(rideMarkerIsBadge(null), isFalse);
      expect(rideMarkerIsBadge(ActivityType.other), isFalse);
    });
    test('every other activity uses the icon badge', () {
      for (final t
          in ActivityType.values.where((t) => t != ActivityType.other)) {
        expect(rideMarkerIsBadge(t), isTrue);
      }
    });
  });
}
