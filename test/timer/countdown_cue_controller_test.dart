import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/timer/countdown_cue_controller.dart';
import 'package:retrail/tracking/countdown_announcer.dart';

class FakeAnnouncer implements CountdownAnnouncer {
  final calls = <String>[];
  @override
  Future<void> prepare(Locale locale) async => calls.add('prepare:$locale');
  @override
  Future<void> count(int second) async => calls.add('$second');
  @override
  Future<void> go() async => calls.add('go');
  @override
  Future<void> stop() async => calls.add('stop');
}

void main() {
  late FakeAnnouncer announcer;
  late bool enabled;

  setUp(() {
    announcer = FakeAnnouncer();
    enabled = true;
  });

  CountdownCueController controller() => CountdownCueController(
    announcer: announcer,
    enabled: () => enabled,
    locale: () => const Locale('de'),
  );

  test('begin readies the voice for the app locale', () {
    controller().begin();
    expect(announcer.calls, ['prepare:de']);
  });

  test('10 → 0 announces 5…1, no go from the tick', () {
    final c = controller()..begin();
    for (var s = 10; s >= 0; s--) {
      c.onValue(s);
    }
    expect(announcer.calls.skip(1), ['5', '4', '3', '2', '1']);
  });

  test('onStart says go', () {
    controller()
      ..begin()
      ..onStart();
    expect(announcer.calls.last, 'go');
  });

  test('a repeated value is announced once', () {
    controller()
      ..begin()
      ..onValue(3)
      ..onValue(3);
    expect(announcer.calls.skip(1), ['3']);
  });

  test('+5 at 3 counts the window again from 5', () {
    final c = controller()..begin();
    for (final s in [5, 4, 3, 8, 7, 6, 5, 4]) {
      c.onValue(s);
    }
    expect(announcer.calls.skip(1), ['5', '4', '3', '5', '4']);
  });

  test('switched off: no voice, no buzz, nothing prepared', () {
    enabled = false;
    controller()
      ..begin()
      ..onValue(5)
      ..onStart()
      ..end();
    expect(announcer.calls, isEmpty);
  });

  test('end cuts a cue still being spoken', () {
    controller()
      ..begin()
      ..onValue(2)
      ..end();
    expect(announcer.calls.last, 'stop');
  });

  test('after go, a late tick (+5 during the start) stays silent', () {
    controller()
      ..begin()
      ..onStart()
      ..onValue(5)
      ..onValue(4);
    expect(announcer.calls.skip(1), ['go']);
  });

  test('the next countdown counts again', () {
    final c = controller()
      ..begin()
      ..onStart()
      ..begin()
      ..onValue(5);
    expect(c, isNotNull);
    expect(announcer.calls.last, '5');
  });
}
