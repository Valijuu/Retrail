import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/home/greeting_selector.dart';

void main() {
  test('shows every greeting once per cycle', () {
    final selector = GreetingSelector(random: Random(1));
    final cycle = [for (var i = 0; i < 5; i++) selector.next(5)];
    expect(cycle.toSet(), {0, 1, 2, 3, 4}); // all distinct, each once
  });

  test('no back-to-back repeat across the cycle boundary', () {
    final selector = GreetingSelector(random: Random(7));
    final seq = [for (var i = 0; i < 30; i++) selector.next(5)];
    for (var i = 1; i < seq.length; i++) {
      expect(seq[i] == seq[i - 1], isFalse, reason: 'repeat at $i: ${seq[i]}');
    }
  });

  test('size 1 always returns 0', () {
    final selector = GreetingSelector(random: Random(1));
    expect([selector.next(1), selector.next(1)], [0, 0]);
  });
}
