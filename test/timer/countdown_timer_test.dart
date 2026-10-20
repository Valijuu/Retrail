import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/timer/countdown_timer.dart';

void main() {
  test('starts at 10 and counts down to 0', () {
    fakeAsync((fa) {
      final t = CountdownTimer()..start();
      expect(t.value, 10);
      fa.elapse(const Duration(seconds: 10));
      expect(t.value, 0);
      expect(t.isFinished, isTrue);
      t.dispose();
    });
  });

  test('does not go negative past 0', () {
    fakeAsync((fa) {
      final t = CountdownTimer()..start();
      fa.elapse(const Duration(seconds: 15));
      expect(t.value, 0);
      t.dispose();
    });
  });

  test('stop freezes the current value', () {
    fakeAsync((fa) {
      final t = CountdownTimer()..start();
      fa.elapse(const Duration(milliseconds: 1500)); // one tick → 9
      final atStop = t.value;
      expect(atStop, 9);
      t.stop();
      fa.elapse(const Duration(seconds: 10));
      expect(t.value, atStop);
      t.dispose();
    });
  });

  test('addTime increases the value immediately', () {
    fakeAsync((fa) {
      final t = CountdownTimer()..start();
      expect(t.value, 10);
      t.addTime(5);
      expect(t.value, 15);
      expect(t.isFinished, isFalse);
      t.dispose();
    });
  });

  test('addTime keeps counting down to 0', () {
    fakeAsync((fa) {
      final t = CountdownTimer()
        ..start()
        ..addTime(5); // → 15
      fa.elapse(const Duration(seconds: 16));
      expect(t.value, 0);
      t.dispose();
    });
  });

  test('notifies listeners on each tick', () {
    fakeAsync((fa) {
      final t = CountdownTimer();
      final seen = <int>[];
      t.addListener(() => seen.add(t.value));
      t.start();
      fa.elapse(const Duration(seconds: 10));
      expect(seen, [10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 0]);
      t.dispose();
    });
  });

  test('dispose cancels the ticker', () {
    fakeAsync((fa) {
      final t = CountdownTimer()..start();
      fa.elapse(const Duration(seconds: 1)); // → 9
      t.dispose();
      // No pending timers should remain after dispose.
      expect(fa.pendingTimers, isEmpty);
    });
  });
}
