import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/tracking/foreground_task_service.dart';
import 'package:retrail/tracking/live_activity_service.dart';

const _copy = RideNotificationCopy(
  channelName: 'Ride tracking',
  recordingTitle: 'Recording ride',
  pausedTitle: 'Ride paused',
  pause: 'Pause',
  resume: 'Resume',
  stop: 'Stop',
  locale: 'en',
);

const _accents = LiveActivityAccents(light: 0xFFB45309, dark: 0xFFF59E42);
const _now = 1700000000000;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late List<MethodCall> calls;
  late bool supported;
  late bool throwing;

  LiveActivityService service() =>
      LiveActivityService(liveActivityChannel, () => _copy, _accents,
          now: () => _now);

  setUp(() {
    calls = [];
    supported = true;
    throwing = false;
    messenger.setMockMethodCallHandler(liveActivityChannel, (call) async {
      calls.add(call);
      if (throwing) throw PlatformException(code: 'boom');
      if (call.method == 'isSupported') return supported;
      return null;
    });
  });

  tearDown(() => messenger.setMockMethodCallHandler(liveActivityChannel, null));

  List<String> methods() => calls.map((c) => c.method).toList();

  test('start sends attributes (labels + ARGB accents) and initial content',
      () async {
    await service().start();

    expect(methods(), ['isSupported', 'start']);
    expect(calls.last.arguments, {
      'attributes': {
        'pauseLabel': 'Pause',
        'resumeLabel': 'Resume',
        'stopLabel': 'Stop',
        'accentLight': 0xFFB45309,
        'accentDark': 0xFFF59E42,
      },
      'content': {
        'title': 'Recording ride',
        'distanceText': '0.00 km',
        'isPaused': false,
        'elapsedSeconds': 0,
        'snapshotEpochMs': _now,
      },
    });
  });

  test('unsupported → start/update/stop send nothing beyond the check',
      () async {
    supported = false;
    final s = service();
    await s.start();
    await s.update(isPaused: false, elapsedSeconds: 5, distanceMetres: 500);
    await s.stop();

    expect(methods(), ['isSupported']);
  });

  test('update before start sends nothing', () async {
    await service()
        .update(isPaused: false, elapsedSeconds: 5, distanceMetres: 500);
    expect(calls, isEmpty);
  });

  test('update pushes only when the visible content changes', () async {
    final s = service();
    await s.start();
    calls.clear();

    // Elapsed alone → the widget counts it natively; no push.
    await s.update(isPaused: false, elapsedSeconds: 1, distanceMetres: 0);
    expect(calls, isEmpty);

    // Distance text changes → push with the new snapshot.
    await s.update(isPaused: false, elapsedSeconds: 2, distanceMetres: 20);
    expect(methods(), ['update']);
    expect(calls.single.arguments, {
      'title': 'Recording ride',
      'distanceText': '0.02 km',
      'isPaused': false,
      'elapsedSeconds': 2,
      'snapshotEpochMs': _now,
    });

    // Pause → push with the paused title.
    calls.clear();
    await s.update(isPaused: true, elapsedSeconds: 3, distanceMetres: 20);
    expect(methods(), ['update']);
    expect((calls.single.arguments as Map)['title'], 'Ride paused');
  });

  test('stop ends the activity; a later update sends nothing', () async {
    final s = service();
    await s.start();
    await s.stop();
    calls.clear();

    await s.update(isPaused: false, elapsedSeconds: 9, distanceMetres: 900);
    expect(calls, isEmpty);
  });

  test('stop sends end', () async {
    final s = service();
    await s.start();
    calls.clear();
    await s.stop();
    expect(methods(), ['end']);
  });

  test('a platform error on any call is swallowed', () async {
    throwing = true;
    final s = service();
    await expectLater(s.start(), completes);
    await expectLater(
        s.update(isPaused: false, elapsedSeconds: 1, distanceMetres: 100),
        completes);
    await expectLater(s.stop(), completes);
  });

  test('a failing start leaves the service inactive', () async {
    final s = service();
    messenger.setMockMethodCallHandler(liveActivityChannel, (call) async {
      calls.add(call);
      if (call.method == 'isSupported') return true;
      throw PlatformException(code: 'denied');
    });
    await s.start();
    calls.clear();

    await s.update(isPaused: true, elapsedSeconds: 1, distanceMetres: 100);
    expect(calls, isEmpty);
  });

  test('no plugin registered (non-iOS / old engine) is swallowed', () async {
    messenger.setMockMethodCallHandler(liveActivityChannel, null);
    await expectLater(service().start(), completes);
  });

  test('ensureNotificationPermission → true (Live Activities need none)',
      () async {
    expect(await service().ensureNotificationPermission(), isTrue);
    expect(calls, isEmpty);
  });

  test('incoming action calls reach the listener with their id', () async {
    final received = <String>[];
    listenForLiveActivityActions(liveActivityChannel, received.add);

    await messenger.handlePlatformMessage(
      liveActivityChannel.name,
      liveActivityChannel.codec
          .encodeMethodCall(const MethodCall('action', 'ride_pause')),
      (_) {},
    );
    expect(received, ['ride_pause']);
    liveActivityChannel.setMethodCallHandler(null);
  });
}
