import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/live_activity_snapshot.dart';

const _recordingTitle = 'Recording ride';
const _pausedTitle = 'Ride paused';
const _snapshotEpochMs = 1700000000000;

LiveActivityContent _content({
  bool isPaused = false,
  int elapsedSeconds = 0,
  double distanceMetres = 0,
  String locale = 'en',
  int nowEpochMs = 0,
}) => liveActivityContent(
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
      expect(
        _content(distanceMetres: 1234, locale: 'en').distanceText,
        '1.23 km',
      );
    });
    test('distanceText — 1234 m in de → "1,23 km"', () {
      expect(
        _content(distanceMetres: 1234, locale: 'de').distanceText,
        '1,23 km',
      );
    });
    test(
      'isPaused, elapsedSeconds and snapshotEpochMs (= now) pass through',
      () {
        final c = _content(
          isPaused: true,
          elapsedSeconds: 125,
          nowEpochMs: _snapshotEpochMs,
        );
        expect(c.isPaused, isTrue);
        expect(c.elapsedSeconds, 125);
        expect(c.snapshotEpochMs, _snapshotEpochMs);
      },
    );
  });

  group('LiveActivityContent', () {
    test('equal fields → equal values and hashCodes', () {
      final a = _content(distanceMetres: 500, elapsedSeconds: 30);
      final b = _content(distanceMetres: 500, elapsedSeconds: 30);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
    test('toMap → the channel content map with all five fields', () {
      final c = _content(
        isPaused: true,
        elapsedSeconds: 125,
        distanceMetres: 1234,
        nowEpochMs: _snapshotEpochMs,
      );
      expect(c.toMap(), {
        'title': _pausedTitle,
        'distanceText': '1.23 km',
        'isPaused': true,
        'elapsedSeconds': 125,
        'snapshotEpochMs': _snapshotEpochMs,
      });
    });
  });

  group('shouldPush', () {
    test('no previous content → true', () {
      expect(shouldPush(null, _content()), isTrue);
    });
    test('only elapsedSeconds / snapshotEpochMs changed → false', () {
      final last = _content(elapsedSeconds: 10, nowEpochMs: 1000);
      final next = _content(elapsedSeconds: 11, nowEpochMs: 2000);
      expect(shouldPush(last, next), isFalse);
    });
    test(
      'distance moved within the same 10 m step (1231 → 1234 m, both "1.23 km") → false',
      () {
        expect(
          shouldPush(
            _content(distanceMetres: 1231),
            _content(distanceMetres: 1234),
          ),
          isFalse,
        );
      },
    );
    test(
      'distance text changed (1234 → 1236 m, "1.23" → "1.24 km") → true',
      () {
        expect(
          shouldPush(
            _content(distanceMetres: 1234),
            _content(distanceMetres: 1236),
          ),
          isTrue,
        );
      },
    );
    test('paused → resumed (isPaused + title flip) → true', () {
      expect(
        shouldPush(_content(isPaused: true), _content(isPaused: false)),
        isTrue,
      );
    });
    test('title changed alone (locale switch) → true', () {
      final english = _content();
      final german = liveActivityContent(
        isPaused: false,
        elapsedSeconds: 0,
        distanceMetres: 0,
        recordingTitle: 'Fahrt wird aufgezeichnet',
        pausedTitle: 'Fahrt pausiert',
        locale: 'en',
        nowEpochMs: 0,
      );
      expect(shouldPush(english, german), isTrue);
    });
    test('keep-alive: nothing changed but 10 min since the last push → true '
        '(keeps a long pause / standstill from going stale)', () {
      const tenMinutesMs = 10 * 60 * 1000;
      // Elapsed ticks along with the clock (standstill while recording), so
      // only the keep-alive interval decides.
      final last = _content(nowEpochMs: _snapshotEpochMs);
      final next = _content(
        elapsedSeconds: 600,
        nowEpochMs: _snapshotEpochMs + tenMinutesMs,
      );
      expect(shouldPush(last, next), isTrue);
    });
    test('nothing changed, just under 10 min since the last push → false', () {
      const justUnderTenMinutesMs = 10 * 60 * 1000 - 1;
      final last = _content(nowEpochMs: _snapshotEpochMs);
      final next = _content(
        elapsedSeconds: 599,
        nowEpochMs: _snapshotEpochMs + justUnderTenMinutesMs,
      );
      expect(shouldPush(last, next), isFalse);
    });
    // #77 review: the widget counts elapsed time natively from the last
    // snapshot; when that count drifts from the real elapsed time (the
    // countdown armed the activity before the ride began at 0) → push.
    group('elapsed drift', () {
      test('ride begins after a 5 s countdown (0 s @0 → 0 s @5000 ms; the '
          'widget would show 5 s) → true', () {
        final armed = _content(elapsedSeconds: 0, nowEpochMs: 0);
        final begun = _content(elapsedSeconds: 0, nowEpochMs: 5000);
        expect(shouldPush(armed, begun), isTrue);
      });
      test('one second of tick jitter (10 s @0 → 10 s @1000 ms) → false', () {
        final last = _content(elapsedSeconds: 10, nowEpochMs: 0);
        final next = _content(elapsedSeconds: 10, nowEpochMs: 1000);
        expect(shouldPush(last, next), isFalse);
      });
      test('drift of exactly 2 s (10 s @0 → 10 s @2000 ms) → true', () {
        final last = _content(elapsedSeconds: 10, nowEpochMs: 0);
        final next = _content(elapsedSeconds: 10, nowEpochMs: 2000);
        expect(shouldPush(last, next), isTrue);
      });
      test('widget behind the real time (10 s @0 → 13 s @1000 ms) → true', () {
        final last = _content(elapsedSeconds: 10, nowEpochMs: 0);
        final next = _content(elapsedSeconds: 13, nowEpochMs: 1000);
        expect(shouldPush(last, next), isTrue);
      });
      test('paused on both sides, time passes (10 s @0 → 10 s @60000 ms) — '
          'the widget does not count while paused → false', () {
        final last = _content(
          isPaused: true,
          elapsedSeconds: 10,
          nowEpochMs: 0,
        );
        final next = _content(
          isPaused: true,
          elapsedSeconds: 10,
          nowEpochMs: 60000,
        );
        expect(shouldPush(last, next), isFalse);
      });
    });
  });
}
