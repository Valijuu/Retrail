import 'dart:async';

import 'package:flutter/foundation.dart';

/// Screen-scoped countdown for the pre-ride timer. Ports `TimerViewModel`:
/// starts at 5, decrements once per second to 0, supports `+time` and `stop`.
///
/// A plain [ChangeNotifier] (no Riverpod) so it's driven by `fake_async` in
/// unit tests and by `tester.pump(Duration)` in widget tests. The owning screen
/// creates it in `initState` and disposes it in `dispose`.
class CountdownTimer extends ChangeNotifier {
  int _value = 5;
  Timer? _ticker;

  /// Seconds remaining.
  int get value => _value;

  /// True once the countdown has reached 0.
  bool get isFinished => _value == 0;

  /// (Re)starts the countdown from [from], setting the value synchronously
  /// (eager first emission, matching the original) before ticking each second.
  void start({int from = 5}) {
    _ticker?.cancel();
    _value = from;
    notifyListeners();
    if (_value <= 0) {
      _ticker = null;
      return;
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_value > 0) {
        _value--;
        notifyListeners();
      }
      if (_value <= 0) {
        _ticker?.cancel();
        _ticker = null;
      }
    });
  }

  /// Restarts the countdown at the current value plus [seconds].
  void addTime(int seconds) => start(from: _value + seconds);

  /// Cancels ticking; the current [value] is held.
  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
