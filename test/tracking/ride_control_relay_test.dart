import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/shell/startup_provider.dart';
import 'package:retrail/tracking/ride_control_relay.dart';
import 'package:retrail/tracking/ride_notification.dart';
import 'package:retrail/tracking/ride_recording_controller.dart';
import 'package:retrail/tracking/ride_tracker.dart';
import 'package:retrail/tracking/ride_tracking_state.dart';
import 'package:retrail/tracking/tracking_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockController extends Mock implements RideRecordingController {}

class _MockTracker extends Mock implements RideTracker {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockController controller;
  late _MockTracker tracker;
  late PreferencesRepository prefs;
  late ProviderContainer container;

  setUp(() async {
    controller = _MockController();
    tracker = _MockTracker();
    when(() => controller.stop()).thenAnswer((_) async {});
    when(
      () => tracker.state,
    ).thenReturn(const RideTrackingState(isTracking: true));
    when(() => tracker.lastCompletedRideId).thenReturn(5);
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesRepository(await SharedPreferences.getInstance());
    container = ProviderContainer(
      overrides: [
        rideRecordingControllerProvider.overrideWithValue(controller),
        rideTrackerProvider.overrideWithValue(tracker),
        preferencesRepositoryProvider.overrideWithValue(prefs),
      ],
    );
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

  // Issue #75: the rider gets an in-app "Ride saved · Add details" hint.
  test('stop → parks the stopped ride for the "Ride saved" hint', () async {
    rideControlRelay(container, RideNotificationIds.stop);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.pendingRideDetailsNow, 5);
  });

  test(
    'stop with no ride recording parks nothing (stale id stays unused)',
    () async {
      when(() => tracker.state).thenReturn(const RideTrackingState());
      rideControlRelay(container, RideNotificationIds.stop);
      await Future<void>.delayed(Duration.zero);
      expect(prefs.pendingRideDetailsNow, isNull);
    },
  );

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
