import 'dart:async';
import 'dart:isolate';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Ride;
import '../../data/repositories/data_providers.dart';
import '../../domain/activity_type.dart';
import '../../domain/heading.dart' show LatLng;
import '../../domain/ride_outline.dart';
import '../history/area_providers.dart';
import '../history/history_items.dart';
import '../history/history_providers.dart';
import 'map_activities.dart';
import 'map_area.dart';
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

  /// The visible rides, by id: a different sort order is the same set.
  final List<int> rideIds;
  final OverviewData? data;

  /// The box around all visible rides, or null when there are none.
  final OutlineBounds? bounds;

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

/// The rides with a route that pass the History filters, once the filters
/// have settled (#96). Outline arrivals do not wait for this, only filter
/// changes do, so the map fills up while the background fill runs.
class SettledMapRidesNotifier extends Notifier<List<Ride>> {
  Timer? _timer;

  List<Ride> _routed(AsyncValue<List<HistoryItem>> items) {
    final types = ref.read(mapActivitiesProvider);
    // With an area set, rides stay hidden until their outline says they are
    // inside it.
    final hasArea = ref.read(settledMapAreaProvider) != null;
    final inArea = hasArea
        ? ref.read(mapAreaRideIdsProvider).value ?? const <int>{}
        : null;
    return [
      for (final item in items.value ?? const <HistoryItem>[])
        if (item is RideEntryItem &&
            item.ride.hasRoute &&
            (inArea == null || inArea.contains(item.ride.rideId)) &&
            mapTypeShown(
              types,
              ActivityType.fromId(item.ride.typ) ?? ActivityType.other,
            ))
          item.ride,
    ];
  }

  @override
  List<Ride> build() {
    ref.onDispose(() => _timer?.cancel());
    void settle() {
      _timer?.cancel();
      _timer = Timer(
        filterDebounce,
        () => state = _routed(ref.read(historyItemsProvider)),
      );
    }

    ref.listen(historyItemsProvider, (_, _) => settle());
    ref.listen(mapActivitiesProvider, (_, _) => settle());
    ref.listen(mapAreaRideIdsProvider, (_, _) => settle());
    return _routed(ref.read(historyItemsProvider));
  }
}

final settledMapRidesProvider =
    NotifierProvider<SettledMapRidesNotifier, List<Ride>>(
      SettledMapRidesNotifier.new,
    );

/// The rides with a drawable outline that pass the History filters, built
/// into map data off the UI thread (#96).
final overviewProvider = FutureProvider<OverviewState>((ref) async {
  final mode = ref.watch(historyMapModeProvider).value ?? HistoryMapMode.lines;
  final rides = ref.watch(settledMapRidesProvider);
  final outlined = ref.watch(outlinedRideIdsProvider).value ?? const <int>{};

  final store = ref.read(outlineStoreProvider);
  await store.refresh(outlined, [for (final r in rides) r.rideId]);
  if (!ref.mounted) return OverviewState.empty;
  final visible = [
    for (final ride in rides)
      if (store.cache[ride.rideId] case final e? when !e.isEmpty) ride,
  ];
  final entries = [for (final ride in visible) store.cache[ride.rideId]!];
  final request = [
    for (var i = 0; i < visible.length; i++)
      OverviewRide(
        rideId: visible[i].rideId,
        typeId: visible[i].typ,
        polyline: entries[i].row.polyline,
        lineFragment: entries[i].lineFragment,
        heatFragment: entries[i].heatFragment,
      ),
  ];
  final bounds = _union([for (final e in entries) e.bounds]);
  final heat = mode == HistoryMapMode.heat;
  final data = await Isolate.run(() => buildOverviewData(request, heat: heat));
  if (!ref.mounted) return OverviewState.empty;
  for (final MapEntry(:key, :value) in data.newLineFragments.entries) {
    store.cache[key]?.lineFragment = value;
  }
  for (final MapEntry(:key, :value) in data.newHeatFragments.entries) {
    store.cache[key]?.heatFragment = value;
  }
  return OverviewState(
    mode: mode,
    rideIds: [for (final r in visible) r.rideId]..sort(),
    data: data,
    bounds: bounds,
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

/// The activity types the history has rides with a route for: what the map
/// legend lists, whatever the activity filter hides.
final legendTypesProvider = StreamProvider<Set<ActivityType>>(
  (ref) => ref
      .watch(rideRepositoryProvider)
      .getAllRides()
      .map(
        (rides) => {
          for (final ride in rides)
            if (ride.hasRoute)
              ActivityType.fromId(ride.typ) ?? ActivityType.other,
        },
      ),
);

/// Where the map camera was last left, kept while the map view is not on
/// screen, so coming back shows the same part of the map at the same zoom.
typedef RememberedCamera = ({LatLng center, double zoom});

class MapCameraMemoryNotifier extends Notifier<RememberedCamera?> {
  @override
  RememberedCamera? build() => null;

  void remember(LatLng center, double zoom) =>
      state = (center: center, zoom: zoom);
}

final mapCameraMemoryProvider =
    NotifierProvider<MapCameraMemoryNotifier, RememberedCamera?>(
      MapCameraMemoryNotifier.new,
    );
