import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/theme_context.dart';
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

class _HistoryMapViewState extends ConsumerState<HistoryMapView> {
  /// Framing is pending after the filters changed, until the new rides arrive.
  bool _framePending = true;
  int _frameToken = 0;
  int _focusToken = 0;
  LatLng? _focus;

  late final MapVisibleNotifier _visible = ref.read(
    mapVisibleProvider.notifier,
  );

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _visible.set(true));
  }

  @override
  void dispose() {
    Future.microtask(() => _visible.set(false));
    super.dispose();
  }

  void _onFilterChanged() => _framePending = true;

  void _onOverview(
    AsyncValue<OverviewState>? previous,
    AsyncValue<OverviewState> next,
  ) {
    final state = next.value;
    if (state == null || !_framePending || state.bounds == null) return;
    setState(() {
      _framePending = false;
      _frameToken++;
    });
  }

  Future<void> _locate() async {
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final locator = ref.read(mapLocatorProvider);
    final result = await locator.locate();
    if (!mounted) return;
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
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.historyMapLocationDenied)),
        );
      case LocateBlocked():
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.historyMapLocationBlocked),
            action: SnackBarAction(
              label: l10n.historyMapOpenSettings,
              onPressed: locator.openAppSettings,
            ),
          ),
        );
      case LocateServicesOff():
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.historyMapLocationOff)),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HistoryFilter>(
      historyFilterProvider,
      (prev, next) => _onFilterChanged(),
    );
    ref.listen(overviewProvider, _onOverview);
    ref.watch(positionFeedProvider);
    ref.watch(outlineFillProvider);

    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final overview = ref.watch(overviewProvider).value ?? OverviewState.empty;
    final mode =
        ref.watch(historyMapModeProvider).value ?? HistoryMapMode.lines;
    final area = ref.watch(historyFilterProvider.select((f) => f.area));
    final selected = ref.watch(selectedRidesProvider);
    final selection = ref.watch(mapSelectionProvider);
    final position = ref.watch(mapPositionProvider);
    final filter = ref.read(historyFilterProvider.notifier);
    final data = overview.data;
    final store = ref.read(outlineStoreProvider);
    final shown = selected.isEmpty
        ? null
        : selected[selection.index.clamp(0, selected.length - 1)];
    final highlightEntry = shown == null
        ? null
        : store.cache[shown.entry.ride.rideId];

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
          highlight: highlightEntry == null || highlightEntry.isEmpty
              ? null
              : linesGeoJson([lineFragment(highlightEntry.row.polyline)]),
          area: area,
          position: position,
          focus: _focus,
          focusToken: _focusToken,
          onTap: ref.read(mapSelectionProvider.notifier).tap,
          onLongPress: filter.setAreaPin,
          onPinMoved: filter.setAreaPin,
          showAttribution: false,
        ),
        Positioned(
          top: 8,
          left: 12,
          right: 12,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MapModeSwitch(
                mode: mode,
                onChanged: ref.read(historyMapControllerProvider).setMode,
              ),
              const SizedBox(height: 6),
              const MapLegend(),
              const SizedBox(height: 6),
              AreaPanel(
                area: area,
                onRadius: filter.setAreaRadius,
                onRemove: filter.clearArea,
              ),
            ],
          ),
        ),
        if (overview.rideIds.isEmpty && !ref.watch(outlineFillProvider))
          Center(
            child: Text(
              l10n.historyNoMatches,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
          ),
        if (ref.watch(outlineFillProvider))
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(
              minHeight: 2,
              semanticsLabel: l10n.historyMapPreparing,
            ),
          ),
        Positioned(
          left: 8,
          right: 8,
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
                  index: selection.index,
                  actions: widget.actions,
                  onSelect: ref.read(mapSelectionProvider.notifier).select,
                  onClose: ref.read(mapSelectionProvider.notifier).clear,
                ),
              const SizedBox(height: kMapAttributionInset),
              MapAttribution(onOpen: openMapCopyright),
            ],
          ),
        ),
      ],
    );
  }
}
