import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/live_activity_snapshot.dart';

const _recordingTitle = 'Recording ride';
const _pausedTitle = 'Ride paused';

LiveActivityContent _content({
  bool isPaused = false,
  int elapsedSeconds = 0,
  double distanceMetres = 0,
  String locale = 'en',
  int nowEpochMs = 0,
}) =>
    liveActivityContent(
      isPaused: isPaused,
      elapsedSeconds: elapsedSeconds,
      distanceMetres: distanceMetres,
      recordingTitle: _recordingTitle,
      pausedTitle: _pausedTitle,
      locale: locale,
      nowEpochMs: nowEpochMs,
    );

void main() {
  group('liveActivityContent', () {
    test('recording → title is the recording title', () {
      expect(_content(isPaused: false).title, _recordingTitle);
    });
    test('paused → title is the paused title', () {
      expect(_content(isPaused: true).title, _pausedTitle);
    });
    test('distanceText — 1234 m in en → "1.23 km"', () {
      expect(_content(distanceMetres: 1234, locale: 'en').distanceText,
          '1.23 km');
    });
    test('distanceText — 1234 m in de → "1,23 km"', () {
      expect(_content(distanceMetres: 1234, locale: 'de').distanceText,
          '1,23 km');
    });
    test('isPaused, elapsedSeconds and snapshotEpochMs (= now) pass through',
        () {
      final c =
          _content(isPaused: true, elapsedSeconds: 125, nowEpochMs: 1700000000000);
      expect(c.isPaused, isTrue);
      expect(c.elapsedSeconds, 125);
      expect(c.snapshotEpochMs, 1700000000000);
    });
  });

  group('LiveActivityContent', () {
    test('equal fields → equal values and hashCodes', () {},
        skip: 'EXACT test list — not yet implemented');
    test('toMap → the channel content map with all five fields', () {},
        skip: 'EXACT test list — not yet implemented');
  });

  group('shouldPush', () {
    test('no previous content → true', () {},
        skip: 'EXACT test list — not yet implemented');
    test('only elapsedSeconds / snapshotEpochMs changed → false', () {},
        skip: 'EXACT test list — not yet implemented');
    test('distance moved within the same 10 m step (1231 → 1239 m) → false',
        () {},
        skip: 'EXACT test list — not yet implemented');
    test('distance crossed a 10 m step (1239 → 1241 m) → true', () {},
        skip: 'EXACT test list — not yet implemented');
    test('paused → resumed (isPaused + title flip) → true', () {},
        skip: 'EXACT test list — not yet implemented');
    test('title changed alone (locale switch) → true', () {},
        skip: 'EXACT test list — not yet implemented');
  });
}
