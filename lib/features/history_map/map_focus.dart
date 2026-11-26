import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ride_outline.dart' show OutlineBounds;
import '../history/area_providers.dart';
import '../history/history_providers.dart';
import 'history_map_providers.dart';
import 'map_activities.dart';
import 'map_area.dart';
import 'outline_fill.dart';

/// The ride the History list asked the map to show (#151), until the map view
/// has dealt with it. Set when the rider picks "Show on map".
class MapFocusNotifier extends Notifier<int?> {
  @override
  int? build() => null;

  void request(int rideId) => state = rideId;

  void clear() => state = null;
}

final mapFocusProvider = NotifierProvider<MapFocusNotifier, int?>(
  MapFocusNotifier.new,
);

/// How long a ride may take to appear on the map after the filters hiding it
/// were reset, before the rider is told it cannot be shown.
const _focusPatience = Duration(milliseconds: 2500);

/// Brings one ride onto the map: waits until the overview holds it, resets
/// what hides it (the shared History filters, the map's activities and its
/// area pin) when it is missing, and reports it as [show]n with its bounds, or
/// as [unavailable] when it never appears (a ride without a drawable route).
class MapFocusFlow {
  MapFocusFlow(this._ref, {required this.show, required this.unavailable});

  final WidgetRef _ref;
  final void Function(int rideId, OutlineBounds? bounds) show;
  final void Function() unavailable;

  int? _rideId;
  bool _reset = false;

  /// A ride is waiting to be shown.
  bool get pending => _rideId != null;
  Timer? _deadline;

  /// A ride to show; replaces one still waiting.
  void start(int rideId) {
    _finish();
    _rideId = rideId;
    advance();
  }

  /// Called whenever the overview or the outline fill changed.
  void advance() {
    final id = _rideId;
    if (id == null) return;
    final overview = _ref.read(overviewProvider);
    final state = overview.value;
    if (overview.isLoading || state == null) return;
    if (state.rideIds.contains(id)) {
      final bounds = _ref.read(outlineStoreProvider).cache[id]?.bounds;
      _finish();
      show(id, bounds);
      return;
    }
    if (_ref.read(outlineFillProvider)) return; // its outline is still coming
    if (_reset) return; // the deadline decides
    _reset = true;
    _ref.read(historyFilterProvider.notifier).reset();
    _ref.read(mapActivitiesProvider.notifier).set(null);
    _ref.read(mapAreaProvider.notifier).clear();
    _deadline = Timer(_focusPatience, _expire);
  }

  void _expire() {
    if (_rideId == null) return;
    // Still loading the refreshed overview (or its outline fill): the ride may
    // yet appear, so the verdict waits for the settled data.
    if (_ref.read(overviewProvider).isLoading ||
        _ref.read(outlineFillProvider)) {
      _deadline = Timer(_focusPatience, _expire);
      return;
    }
    _finish();
    unavailable();
  }

  void _finish() {
    _deadline?.cancel();
    _deadline = null;
    _rideId = null;
    _reset = false;
  }

  void dispose() => _deadline?.cancel();
}
