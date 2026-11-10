import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../history/history_providers.dart';

/// Whether the app is in front. The background fill stops otherwise (#96).
class AppForegroundNotifier extends Notifier<bool> with WidgetsBindingObserver {
  @override
  bool build() {
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(() => WidgetsBinding.instance.removeObserver(this));
    return WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    this.state = state == AppLifecycleState.resumed;
  }
}

final appForegroundProvider = NotifierProvider<AppForegroundNotifier, bool>(
  AppForegroundNotifier.new,
);

/// True while the History map view is on screen.
class MapVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool visible) => state = visible;
}

final mapVisibleProvider = NotifierProvider<MapVisibleNotifier, bool>(
  MapVisibleNotifier.new,
);

/// Gives old rides their outline in the background, one ride at a time with a
/// pause in between, while the map is on screen or an area is set and the app
/// is in front (#96). The state says whether a fill is running.
class OutlineFillController extends Notifier<bool> {
  @override
  bool build() {
    final wanted =
        (ref.watch(mapVisibleProvider) ||
            ref.watch(historyFilterProvider.select((f) => f.area != null))) &&
        ref.watch(appForegroundProvider);
    _wanted = wanted;
    if (wanted) Future.microtask(_run);
    return false;
  }

  bool _wanted = false;
  bool _running = false;

  Future<void> _run() async {
    if (_running || !_wanted) return;
    _running = true;
    state = true;
    try {
      final repo = ref.read(outlineRepositoryProvider);
      while (_wanted && ref.mounted) {
        final more = await repo.fillNext();
        if (!more) break;
        await Future<void>.delayed(Duration.zero);
      }
    } finally {
      _running = false;
      if (ref.mounted) state = false;
    }
  }
}

final outlineFillProvider = NotifierProvider<OutlineFillController, bool>(
  OutlineFillController.new,
);
