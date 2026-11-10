import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../../domain/activity_type.dart';
import '../../domain/ride_outline.dart';
import '../history/area_providers.dart';
import '../history/history_items.dart';
import '../history/history_providers.dart';
import 'overview_geojson.dart';
import 'route_badges.dart';

/// The History tab's two views (#96).
enum HistoryView { list, map }

/// How the map draws the visible rides.
enum HistoryMapMode { lines, heat }

final historyViewProvider = StreamProvider<HistoryView>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .historyView
      .map((id) => HistoryView.values.asNameMap()[id] ?? HistoryView.list),
);

final historyMapModeProvider = StreamProvider<HistoryMapMode>(
  (ref) => ref
      .watch(preferencesRepositoryProvider)
      .historyMapMode
      .map(
        (id) => HistoryMapMode.values.asNameMap()[id] ?? HistoryMapMode.lines,
      ),
);

/// Intent methods for the view and mode choice.
class HistoryMapController {
  HistoryMapController(this._ref);
  final Ref _ref;

  Future<void> setView(HistoryView view) =>
      _ref.read(preferencesRepositoryProvider).setHistoryView(view.name);

  Future<void> setMode(HistoryMapMode mode) =>
      _ref.read(preferencesRepositoryProvider).setHistoryMapMode(mode.name);
}

final historyMapControllerProvider = Provider<HistoryMapController>(
  HistoryMapController.new,
);

/// What the map shows: the visible rides' data plus their ids and framing.
class OverviewState {
  const OverviewState({
    required this.mode,
    required this.rideIds,
    required this.data,
    required this.bounds,
  });

  static const empty = OverviewState(
    mode: HistoryMapMode.lines,
    rideIds: [],
    data: null,
    bounds: null,
  );

  final HistoryMapMode mode;

  /// The visible rides, newest first as the list shows them.
  final List<int> rideIds;
  final OverviewData? data;

  /// The box around all visible rides, or null when there are none.
  final OutlineBounds? bounds;

  /// Visible rides per activity type (the legend counts).
  Map<ActivityType, int> get countByType => {
    for (final e in (data?.countByType ?? const <String, int>{}).entries)
      ActivityType.fromId(e.key) ?? ActivityType.other: e.value,
  };

  // The map is pushed again only when the visible set or the mode changes.
  @override
  bool operator ==(Object other) =>
      other is OverviewState &&
      other.mode == mode &&
      other.rideIds.length == rideIds.length &&
      _sameIds(other.rideIds);

  bool _sameIds(List<int> ids) {
    for (var i = 0; i < ids.length; i++) {
      if (ids[i] != rideIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(mode, Object.hashAll(rideIds));
}

/// The rides with a drawable outline that pass the History filters, built
/// into map data off the UI thread once the filters settle (#96).
final overviewProvider = FutureProvider<OverviewState>((ref) async {
  final mode = ref.watch(historyMapModeProvider).value ?? HistoryMapMode.lines;
  final rides = [
    for (final item in ref.watch(historyItemsProvider).value ?? const [])
      if (item is RideEntryItem && item.ride.hasRoute) item.ride,
  ];
  final outlined = ref.watch(outlinedRideIdsProvider).value ?? const <int>{};
  await Future<void>.delayed(filterDebounce);
  if (!ref.mounted) return OverviewState.empty;

  final store = ref.read(outlineStoreProvider);
  await store.refresh(outlined, [for (final r in rides) r.rideId]);
  final visible = [
    for (final ride in rides)
      if (store.cache[ride.rideId] case final e? when !e.isEmpty) ride,
  ];
  final request = [
    for (final ride in visible)
      OverviewRide(
        rideId: ride.rideId,
        typeId: ride.typ,
        polyline: store.cache[ride.rideId]!.row.polyline,
        lineFragment: store.cache[ride.rideId]!.lineFragment,
        heatFragment: store.cache[ride.rideId]!.heatFragment,
      ),
  ];
  final heat = mode == HistoryMapMode.heat;
  final data = await Isolate.run(() => buildOverviewData(request, heat: heat));
  for (final MapEntry(:key, :value) in data.newLineFragments.entries) {
    store.cache[key]?.lineFragment = value;
  }
  for (final MapEntry(:key, :value) in data.newHeatFragments.entries) {
    store.cache[key]?.heatFragment = value;
  }
  return OverviewState(
    mode: mode,
    rideIds: [for (final r in visible) r.rideId],
    data: data,
    bounds: _union([for (final r in visible) store.cache[r.rideId]!.bounds]),
  );
});

OutlineBounds? _union(List<OutlineBounds> boxes) {
  if (boxes.isEmpty) return null;
  return (
    south: boxes.map((b) => b.south).reduce((a, b) => a < b ? a : b),
    west: boxes.map((b) => b.west).reduce((a, b) => a < b ? a : b),
    north: boxes.map((b) => b.north).reduce((a, b) => a > b ? a : b),
    east: boxes.map((b) => b.east).reduce((a, b) => a > b ? a : b),
  );
}

/// Which rides hold the best time of their route group, over all rides.
final routeBadgesProvider = StreamProvider<RouteBadges>(
  (ref) => ref.watch(rideRepositoryProvider).getAllRides().map(routeBadges),
);
