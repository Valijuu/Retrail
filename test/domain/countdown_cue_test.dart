import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/countdown_cue.dart';

void main() {
  group('countdownCueFor', () {
    test('well before the end (10 s left) — no cue (null)', () {
      expect(countdownCueFor(10), isNull);
    });
    test('one second before the cue window (6 s left) — null', () {
      expect(countdownCueFor(6), isNull);
    });
    test('the window opens (5 s left) — announces 5', () {
      expect(countdownCueFor(5), 5);
    });
    test('the last second (1 s left) — announces 1', () {
      expect(countdownCueFor(1), 1);
    });
    test(
      'every second inside the window (4, 3, 2) — announces that second',
      () {
        expect([4, 3, 2].map(countdownCueFor), [4, 3, 2]);
      },
    );
    test('zero — null ("go" comes from the start path, not the tick)', () {
      expect(countdownCueFor(0), isNull);
    });
    test('negative (-1) — null', () {
      expect(countdownCueFor(-1), isNull);
    });
    test('extended with +5 (15 s left) — null', () {
      expect(countdownCueFor(15), isNull);
    });
    test('the window starts at countdownCueFrom (5)', () {
      expect(countdownCueFrom, 5);
      expect(countdownCueFor(countdownCueFrom + 1), isNull);
      expect(countdownCueFor(countdownCueFrom), countdownCueFrom);
    });
  });
}
