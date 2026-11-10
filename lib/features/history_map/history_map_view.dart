import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_context.dart';
import '../../core/widgets/app_snack_bar.dart';
import '../../domain/activity_type.dart';
import '../../domain/heading.dart' show LatLng;
import '../../l10n/app_localizations.dart';
import '../../map/overview_map.dart';
import '../../map/map_attribution.dart';
import '../history/area_providers.dart';
import '../history/history_filter.dart';
import '../history/history_providers.dart';
import 'history_map_providers.dart';
import 'map_locator.dart';
import 'map_selection.dart';
import 'outline_fill.dart';
import 'overview_geojson.dart';
import 'widgets/map_controls.dart';
import 'widgets/map_legend.dart';
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
const double _cardInset = 8;
const double _progressHeight = 2;

/// How long after a filter change the next new set of rides is framed.
const Duration _frameWindow = Duration(seconds: 2);

/// What a filter change means for the camera: the rides it selects. Sort,
/// and the radius while the pin stays, do not reframe.
Object _framingKey(HistoryFilter f) => Object.hash(
  f.query.trim(),
  f.favoritesOnly,
  Object.hashAllUnordered(f.activities),
  f.year,
  f.monthFrom,
  f.monthTo,
  Object.hashAllUnordered(f.routeIds),
  f.area?.pin,
);

class _HistoryMapViewState extends ConsumerState<HistoryMapView> {
  /// The camera frames the visible rides once after the filters changed, when
  /// the new set has arrived; and once when the view opens without data.
  bool _framePending = false;
  Timer? _frameWindowTimer;
  List<int>? _framedIds;
  int _frameToken = 0;
  int _focusToken = 0;
  LatLng? _focus;

  late final MapVisibleNotifier _visible = ref.read(
    mapVisibleProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    final bounds = ref.read(overviewProvider).value?.bounds;
    _framePending = bounds == null;
    Future.microtask(() => _visible.set(true));
  }

  @override
  void dispose() {
    _frameWindowTimer?.cancel();
    Future.microtask(() => _visible.set(false));
    super.dispose();
  }

  void _onFilterChanged(HistoryFilter? previous, HistoryFilter next) {
    if (previous == null || _framingKey(previous) == _framingKey(next)) return;
    _framePending = true;
    _frameWindowTimer?.cancel();
    _frameWindowTimer = Timer(_frameWindow, () => _framePending = false);
  }

  void _onOverview(
    AsyncValue<OverviewState>? previous,
    AsyncValue<OverviewState> next,
  ) {
    final state = next.value;
    // A reload still carries the old rides: wait for the new ones. While old
    // rides are still being given their outline the set is not complete yet.
    if (next.isLoading || state == null || state.bounds == null) return;
    if (ref.read(outlineFillProvider)) return;
    final sameSet = _framedIds != null && _sameIds(_framedIds!, state.rideIds);
    if (!_framePending || sameSet) return;
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
        ref.read(historyFilterProvider.notifier).setAreaPin(position);
        setState(() {
          _focus = position;
          _focusToken++;
        });
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
    ref.listen(overviewProvider, _onOverview);
    ref.listen(outlineFillProvider, (was, filling) {
      if (was == true && !filling) {
        _onOverview(null, ref.read(overviewProvider));
      }
    });
    ref.watch(positionFeedProvider);
    final filling = ref.watch(outlineFillProvider);

    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final overviewAsync = ref.watch(overviewProvider);
    final overview = overviewAsync.value ?? OverviewState.empty;
    final mode =
        ref.watch(historyMapModeProvider).value ?? HistoryMapMode.lines;
    final area = ref.watch(historyFilterProvider.select((f) => f.area));
    final selected = ref.watch(selectedRidesProvider);
    final shownIndex = ref.watch(shownRideIndexProvider);
    final position = ref.watch(mapPositionProvider);
    final filter = ref.read(historyFilterProvider.notifier);
    final selection = ref.read(mapSelectionProvider.notifier);
    final data = overview.data;
    final shown = selected.isEmpty ? null : selected[shownIndex];
    final highlight = shown == null
        ? null
        : _highlightOf(ref.read(outlineStoreProvider), shown);
    final noRides =
        overviewAsync.hasValue &&
        !overviewAsync.isLoading &&
        overview.rideIds.isEmpty &&
        !filling;

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
          area: area,
          position: position,
          focus: _focus,
          focusToken: _focusToken,
          onTap: selection.tap,
          onLongPress: filter.setAreaPin,
          onPinMoved: filter.setAreaPin,
          showAttribution: false,
        ),
        Positioned(
          top: _topInset,
          left: _edgeInset,
          right: _edgeInset,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MapModeSwitch(
                mode: mode,
                onChanged: ref.read(historyMapControllerProvider).setMode,
              ),
              const SizedBox(height: _panelGap),
              const MapLegend(),
              const SizedBox(height: _panelGap),
              AreaPanel(
                area: area,
                onRadius: filter.setAreaRadius,
                onRemove: filter.clearArea,
              ),
            ],
          ),
        ),
        if (noRides)
          Center(
            child: Text(
              l10n.historyNoMatches,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
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
                  rides: selected,
                  index: shownIndex,
                  actions: widget.actions,
                  onSelect: selection.show,
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

  /// The tapped ride's line, built once and kept with its cached outline.
  String? _highlightOf(OutlineStore store, SelectedRide ride) {
    final entry = store.cache[ride.entry.ride.rideId];
    if (entry == null || entry.isEmpty) return null;
    final fragment = entry.lineFragment ??= lineFragment(entry.row.polyline);
    return linesGeoJson([fragment]);
  }
}
