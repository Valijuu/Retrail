import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/features/shell/startup_provider.dart';
import 'package:retrail/tracking/ride_control_relay.dart';
import 'package:retrail/tracking/ride_notification.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/tracking_providers.dart';

class _MockController extends Mock implements RideRecordingController {}

void main() {
  late _MockController controller;
  late ProviderContainer container;

  setUp(() {
    controller = _MockController();
    when(() => controller.stop()).thenAnswer((_) async {});
    container = ProviderContainer(overrides: [
      rideRecordingControllerProvider.overrideWithValue(controller),
    ]);
  });

  tearDown(() => container.dispose());

  test('pause → pauses the recording ride', () {
    rideControlRelay(container, RideNotificationIds.pause);
    verify(() => controller.pauseOrResume(false)).called(1);
  });

  test('resume → resumes the paused ride', () {
    rideControlRelay(container, RideNotificationIds.resume);
    verify(() => controller.pauseOrResume(true)).called(1);
  });

  test('stop → finalizes the ride', () {
    rideControlRelay(container, RideNotificationIds.stop);
    verify(() => controller.stop()).called(1);
  });

  test('open → requests the active-ride deep link, no controller call', () {
    rideControlRelay(container, RideNotificationIds.open);
    expect(container.read(pendingRideDeepLinkProvider), isTrue);
    verifyZeroInteractions(controller);
  });

  test('unknown id → ignored', () {
    rideControlRelay(container, 'something_else');
    expect(container.read(pendingRideDeepLinkProvider), isFalse);
    verifyZeroInteractions(controller);
  });
}
