import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/tracking/ride_notification.dart';

void main() {
  test('maps notification button ids to ride actions', () {
    expect(rideActionFromId(RideNotificationIds.pause), RideAction.pause);
    expect(rideActionFromId(RideNotificationIds.resume), RideAction.resume);
    expect(rideActionFromId(RideNotificationIds.stop), RideAction.stop);
  });

  test('unknown id maps to null', () {
    expect(rideActionFromId('bogus'), isNull);
    expect(rideActionFromId(''), isNull);
  });
}
