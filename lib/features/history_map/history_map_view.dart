import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/app_snack_bar.dart';
import '../../domain/activity_type.dart';
import '../../domain/route_markers.dart'
    show RouteEndpointStyle, routeEndpointStyle;
import '../../map/overview_layers.dart' show OverviewEnds;
import '../../l10n/app_localizations.dart';
import '../../map/overview_map.dart';
import '../../map/map_attribution.dart';
import '../history/area_providers.dart';
import '../history/history_filter.dart';
import '../history/history_providers.dart';
import 'history_map_providers.dart';
import '../home/home_providers.dart' show lastActivityTypeProvider;
import 'map_area.dart';
import 'map_default_activity.dart';
import 'map_locator.dart';
import 'map_selection.dart';
import 'outline_fill.dart';
import 'overview_geojson.dart';
import 'widgets/map_controls.dart';
import 'widgets/activity_menu.dart';
import 'widgets/map_preview_card.dart';

/// The map view of the History tab (#96): every ride with a route as a line
/// or heat, the legend, the area pin and radius, the position button and the
/// preview card of the tapped ride. The History screen passes the card's
/// [actions].
class HistoryMapView extends ConsumerStatefulWidget {
  const HistoryMapView({super.key, required this.actions});

  final MapCardActions actions;

  @override
  ConsumerState<HistoryMapView> createState() => _HistoryMapViewState();
}

/// Space between the map's edge and the controls laid over it.
const double _edgeInset = 12;
const double _topInset = 8;
const double _panelGap = 6;

/// Side space of the ride card over the map: narrow, so the map stays in view.
const double _cardInset = 28;
const double _progressHeight = 2;

/// What a filter change means for the camera: the rides it selects. Sort and
/// the area do not reframe; the map fits the area circle itself.
Object _framingKey(HistoryFilter f) => Object.hash(
  f.query.trim(),
  f.favoritesOnly,
  f.year,
  f.monthFrom,
  f.monthTo,
  Object.hashAllUnordered(f.routeIds),
);

class _HistoryMapViewState extends ConsumerState<HistoryMapView> {
  /// The camera frames the visible rides once after the filters changed, when
  /// the new set has arrived; and once when the view opens without data. It
  /// waits however long the new set takes; a camera gesture cancels it.
  bool _framePending = false;
  List<int>? _framedIds;
  int _frameToken = 0;
  int _areaFocusToken = 0;

  /// Where the camera was left on the last visit; null on the first one.
  late final RememberedCamera? _restore = ref.read(mapCameraMemoryProvider);

  late final MapVisibleNotifier _visible = ref.read(
    mapVisibleProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    final bounds = ref.read(overviewProvider).value?.bounds;
    _framePending = bounds == null && _restore == null;
    Future.microtask(() {
      _visible.set(true);
      if (mounted) _applyDefaultActivity();
    });
  }

  @override
  void dispose() {
    Future.microtask(() => _visible.set(false));
    super.dispose();
  }

  void _onFilterChanged(HistoryFilter? previous, HistoryFilter next) {
    if (previous == null || _framingKey(previous) == _framingKey(next)) return;
    _reframe();
  }

  /// The rider's own activity as the map's start: the camera frames that set
  /// once. The rider's own ticks in the activity menu never move the camera.
  void _applyDefaultActivity() {
    if (applyMapDefaultActivity(ref)) _reframe();
  }

  /// The camera frames the new set of rides once when it arrives.
  void _reframe() => _framePending = true;

  /// A gesture of the rider is never overridden by a frame still waiting.
  void _onUserMoved() => _framePending = false;

  void _onOverview(
    AsyncValue<OverviewState>? previous,
    AsyncValue<OverviewState> next,
  ) {
    final state = next.value;
    // A reload still carries the old rides: wait for the new ones. While old
    // rides are still being given their outline the set is not complete yet.
    if (next.isLoading || state == null || state.bounds == null) return;
    if (ref.read(outlineFillProvider)) return;
    if (!_framePending) return;
    // The new set is through: frame it once, unless the camera shows it
    // already. Either way nothing is left waiting for a later change.
    if (_framedIds != null && _sameIds(_framedIds!, state.rideIds)) {
      _framePending = false;
      return;
    }
    setState(() {
      _framePending = false;
      _framedIds = state.rideIds;
      _frameToken++;
    });
  }

  bool _sameIds(List<int> a, List<int> b) =>
      a.length == b.length &&
      Iterable<int>.generate(a.length).every((i) => a[i] == b[i]);

  Future<void> _locate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locator = ref.read(mapLocatorProvider);
    final result = await locator.locate();
    if (!mounted) return;
    void hint(String message, {SnackBarAction? action}) =>
        messenger.showSnackBar(
          appSnackBar(
            icon: Icons.location_off,
            message: message,
            action: action,
          ),
        );
    switch (result) {
      case Located(:final position):
        ref.read(locationEnabledProvider.notifier).enable();
        ref.read(mapPositionProvider.notifier).set(position);
        ref.read(mapAreaProvider.notifier).setPin(position);
        // Like a long press: the camera shows the pin's whole circle.
        setState(() => _areaFocusToken++);
      case LocateDenied():
        hint(l10n.historyMapLocationDenied);
      case LocateBlocked():
        hint(
          l10n.historyMapLocationBlocked,
          action: SnackBarAction(
            label: l10n.historyMapOpenSettings,
            onPressed: locator.openAppSettings,
          ),
        );
      case LocateServicesOff():
        hint(l10n.historyMapLocationOff);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HistoryFilter>(historyFilterProvider, _onFilterChanged);
    ref.listen(legendTypesProvider, (_, _) => _applyDefaultActivity());
    ref.listen(lastActivityTypeProvider, (_, _) => _applyDefaultActivity());
    ref.listen(overviewProvider, _onOverview);
    ref.listen(outlineFillProvider, (was, filling) {
      if (was == true && !filling) {
        _onOverview(null, ref.read(overviewProvider));
      }
    });
    ref.watch(positionFeedProvider);
    final filling = ref.watch(outlineFillProvider);

    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(overviewProvider).value ?? OverviewState.empty;
    final mode =
        ref.watch(historyMapModeProvider).value ?? HistoryMapMode.lines;
    final area = ref.watch(mapAreaProvider);
    final shown = ref.watch(selectedRideProvider);
    final position = ref.watch(mapPositionProvider);
    final areaNotifier = ref.read(mapAreaProvider.notifier);
    final selection = ref.read(mapSelectionProvider.notifier);
    final data = overview.data;
    final highlight = shown == null
        ? null
        : _highlightOf(ref.read(outlineStoreProvider), shown);
    final ends = shown == null
        ? null
        : _endsOf(ref.read(outlineStoreProvider), shown);

    return Stack(
      fit: StackFit.expand,
      children: [
        OverviewMap(
          linesByType: {
            for (final e
                in (data?.linesByType ?? const <String, String>{}).entries)
              ActivityType.fromId(e.key) ?? ActivityType.other: e.value,
          },
          heat: mode == HistoryMapMode.heat ? data?.heat : null,
          bounds: overview.bounds,
          frameToken: _frameToken,
          highlight: highlight,
          highlightEnds: ends,
          area: area,
          position: position,
          areaFocusToken: _areaFocusToken,
          onTap: selection.tap,
          onLongPress: areaNotifier.setPin,
          onPinMoved: areaNotifier.setPin,
          restoreCamera: _restore,
          onCameraIdle: ref.read(mapCameraMemoryProvider.notifier).remember,
          onUserMoved: _onUserMoved,
          showAttribution: false,
        ),
        Positioned(
          top: _topInset,
          left: _edgeInset,
          right: _edgeInset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  MapModeSwitch(
                    mode: mode,
                    onChanged: ref.read(historyMapControllerProvider).setMode,
                  ),
                  const SizedBox(width: _panelGap),
                  const ActivityMenu(),
                ],
              ),
              if (area != null) ...[
                const SizedBox(height: _panelGap),
                AreaPanel(
                  area: area,
                  onRadius: areaNotifier.setRadius,
                  onRemove: areaNotifier.clear,
                ),
              ],
            ],
          ),
        ),
        if (filling)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: _progressHeight,
              semanticsLabel: l10n.historyMapPreparing,
            ),
          ),
        Positioned(
          left: _cardInset,
          right: _cardInset,
          bottom: kMapAttributionInset,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (shown == null)
                Align(
                  alignment: Alignment.centerRight,
                  child: MyLocationButton(onPressed: _locate),
                )
              else
                MapPreviewCard(
                  ride: shown,
                  actions: widget.actions,
                  onClose: selection.clear,
                ),
              const SizedBox(height: kMapAttributionInset),
              MapAttribution(onOpen: openMapCopyright),
            ],
          ),
        ),
      ],
    );
  }

  /// Where the tapped ride starts and finishes: one combined marker for a
  /// loop, a start and a finish otherwise (the preview's rule).
  OverviewEnds? _endsOf(OutlineStore store, SelectedRide ride) {
    final entry = store.cache[ride.entry.ride.rideId];
    if (entry == null || entry.isEmpty) return null;
    final points = entry.outline.points;
    switch (routeEndpointStyle(points)) {
      case RouteEndpointStyle.none:
        return null;
      case RouteEndpointStyle.startOnly:
        return OverviewEnds(start: points.first);
      case RouteEndpointStyle.loop:
        return OverviewEnds(loop: points.first);
      case RouteEndpointStyle.open:
        return OverviewEnds(start: points.first, finish: points.last);
    }
  }

  /// The tapped ride's line, built once and kept with its cached outline.
  String? _highlightOf(OutlineStore store, SelectedRide ride) {
    final entry = store.cache[ride.entry.ride.rideId];
    if (entry == null || entry.isEmpty) return null;
    final fragment = entry.lineFragment ??= lineFragment(entry.row.polyline);
    return linesGeoJson([fragment]);
  }
}
