import 'dart:math' as math;

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../core/theme/theme_context.dart';
import '../domain/activity_type.dart';
import '../domain/area_filter.dart';
import '../domain/heading.dart' show LatLng;
import '../domain/ride_outline.dart' show OutlineBounds;
import 'live_map.dart' show kLiveMapMaxZoom, kLiveMapMinZoom, liveMapStyle;
import 'map_attribution.dart';
import 'overview_layers.dart';
import 'overview_pin.dart';
import 'preview_projection.dart' show RoutePoint;
import 'route_camera.dart';

/// Kilometres per degree of latitude on the Haversine sphere.
const double _kmPerDegreeLat = 111.195;

/// Zoom the my-location button moves the camera to.
const double kOverviewLocationZoom = 15;

/// The overview map of the History map view (#96): every visible ride as
/// lines from one GeoJSON source per activity type, or as one heatmap, plus
/// the area circle and pin, the highlighted ride and the user position. It
/// follows the live map's rules for the style load, disposal and the
/// light/dark switch (#43, #47) and always shows the attribution.
class OverviewMap extends StatefulWidget {
  const OverviewMap({
    super.key,
    required this.linesByType,
    required this.heat,
    required this.bounds,
    required this.frameToken,
    this.highlight,
    this.area,
    this.position,
    this.focus,
    this.focusToken,
    this.onTap,
    this.onLongPress,
    this.onPinMoved,
    this.onCameraIdle,
    this.restoreCamera,
    this.showAttribution = true,
  });

  /// Line GeoJSON per activity type; a missing type draws nothing.
  final Map<ActivityType, String> linesByType;

  /// Heat GeoJSON, drawn instead of the lines when set.
  final String? heat;

  /// The box around all visible rides, for the framing.
  final OutlineBounds? bounds;

  /// Changes when the filters change: the map frames the visible rides again.
  /// A user gesture stops framing until the next change.
  final Object? frameToken;

  /// GeoJSON of the tapped ride, drawn on top.
  final String? highlight;
  final AreaFilter? area;
  final LatLng? position;

  /// Moves the camera to [focus] at [kOverviewLocationZoom] when [focusToken]
  /// changes (the my-location button).
  final LatLng? focus;
  final Object? focusToken;

  /// A tap on the map, with the zoom it happened at.
  final void Function(LatLng point, double zoom)? onTap;
  final ValueChanged<LatLng>? onLongPress;
  final ValueChanged<LatLng>? onPinMoved;

  /// Reports where the camera came to rest, to be kept for a later visit.
  final void Function(LatLng center, double zoom)? onCameraIdle;

  /// Starts at this camera instead of framing the rides (coming back to the
  /// map after leaving it).
  final ({LatLng center, double zoom})? restoreCamera;

  /// Whether the map draws its own attribution. A screen that stacks content
  /// at the bottom turns it off and shows the credit with that content.
  final bool showAttribution;

  /// Test seam: when set, every [OverviewMap] renders this instead of the
  /// native map, which throws under `flutter test`.
  @visibleForTesting
  static Widget Function(BuildContext context)? debugMapBuilderOverride;

  @override
  State<OverviewMap> createState() => _OverviewMapState();
}

class _OverviewMapState extends State<OverviewMap> {
  final GlobalKey _mapKey = GlobalKey();
  MapController? _controller;
  StyleController? _style;
  bool _sourcesReady = false;
  bool _styleReady = false;
  bool _userMoved = false;
  Size _viewport = Size.zero;
  Brightness? _brightness;

  /// What each source holds now, so an unchanged payload is not pushed again.
  final Map<String, String> _pushed = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A light/dark switch rebuilds the native map: cut the old one off now so
    // no update reaches a disposed map (#43).
    final brightness = Theme.of(context).brightness;
    if (_brightness != null && brightness != _brightness) _detach();
    _brightness = brightness;
  }

  void _detach() {
    _controller = null;
    _style = null;
    _sourcesReady = false;
    _pushed.clear();
  }

  @override
  void didUpdateWidget(OverviewMap old) {
    super.didUpdateWidget(old);
    if (_sourcesReady) _pushAll();
    final area = widget.area;
    if (area != null &&
        (old.area == null || area.radiusKm != old.area!.radiusKm)) {
      _fitArea(area);
    }
    if (widget.frameToken != old.frameToken) {
      _userMoved = false;
      _frame();
    } else if (!_userMoved &&
        widget.restoreCamera == null &&
        widget.bounds != old.bounds &&
        old.bounds == null) {
      _frame();
    }
    if (widget.focusToken != old.focusToken && widget.focus != null) {
      _userMoved = true;
      _jump(widget.focus!, kOverviewLocationZoom);
    }
  }

  void _push(String id, String data) {
    if (_pushed[id] == data) return;
    _pushed[id] = data;
    _style?.updateGeoJsonSource(id: id, data: data);
  }

  void _pushAll() {
    final heat = widget.heat;
    for (final type in ActivityType.values) {
      _push(
        overviewSourceId(type),
        heat == null
            ? widget.linesByType[type] ?? emptyOverviewGeoJson
            : emptyOverviewGeoJson,
      );
    }
    _push(overviewHeatSource, heat ?? emptyOverviewGeoJson);
    _push(overviewHighlightSource, widget.highlight ?? emptyOverviewGeoJson);
    final area = widget.area;
    _push(
      overviewAreaSource,
      area == null
          ? emptyOverviewGeoJson
          : areaCircleGeoJson(area.pin, area.radiusKm),
    );
    _push(overviewPositionSource, overviewPointGeoJson(widget.position));
  }

  bool _superseded(StyleController style) =>
      !mounted || !identical(_style, style);

  Future<void> _onStyleLoaded(StyleController style) async {
    _style = style;
    _sourcesReady = false;
    _pushed.clear();
    final colors = context.colors;
    final brightness = Theme.of(context).brightness;
    await addOverviewLayers(
      style,
      colors: colors,
      brightness: brightness,
      stale: () => _superseded(style),
    );
    if (_superseded(style)) return;
    _sourcesReady = true;
    _pushAll();
    final restore = widget.restoreCamera;
    if (restore != null) {
      await _jump(restore.center, restore.zoom);
    } else {
      await _frame();
    }
    if (mounted && !_styleReady) setState(() => _styleReady = true);
  }

  Future<void> _frame() async {
    final box = widget.bounds;
    if (box == null || _viewport.isEmpty || _controller == null) return;
    final fit = fitRouteCamera(
      <RoutePoint>[
        (lat: box.south, lng: box.west),
        (lat: box.north, lng: box.east),
      ],
      width: _viewport.width,
      height: _viewport.height,
    );
    if (fit == null) return;
    await _jump((lat: fit.lat, lng: fit.lng), fit.zoom);
  }

  /// Zooms to show the whole area circle, so a larger radius zooms out.
  Future<void> _fitArea(AreaFilter area) async {
    if (_viewport.isEmpty) return;
    final dLat = area.radiusKm / _kmPerDegreeLat;
    final dLng = dLat / math.max(math.cos(area.pin.lat * math.pi / 180), 0.01);
    final fit = fitRouteCamera(
      <RoutePoint>[
        (lat: area.pin.lat - dLat, lng: area.pin.lng - dLng),
        (lat: area.pin.lat + dLat, lng: area.pin.lng + dLng),
      ],
      width: _viewport.width,
      height: _viewport.height,
    );
    if (fit == null) return;
    _userMoved = true;
    await _jump((lat: fit.lat, lng: fit.lng), fit.zoom);
  }

  /// Moves first and then zooms at the new centre (#41), north-up.
  Future<void> _jump(LatLng to, double zoom) async {
    final controller = _controller;
    if (controller == null) return;
    final center = Geographic(lon: to.lng, lat: to.lat);
    try {
      await controller.moveCamera(center: center, bearing: 0);
      await controller.moveCamera(center: center, zoom: zoom);
    } catch (_) {
      // A superseded move is expected while the user drags.
    }
  }

  void _onEvent(MapEvent e) {
    switch (e) {
      case MapEventStartMoveCamera(reason: CameraChangeReason.apiGesture):
        _userMoved = true;
      case MapEventClick(:final point):
        widget.onTap?.call((
          lat: point.lat,
          lng: point.lon,
        ), _controller?.camera?.zoom ?? kLiveMapMinZoom);
      case MapEventCameraIdle():
        final camera = _controller?.camera;
        if (camera != null) {
          widget.onCameraIdle?.call((
            lat: camera.center.lat,
            lng: camera.center.lon,
          ), camera.zoom);
        }
      case MapEventLongClick(:final point):
        widget.onLongPress?.call((lat: point.lat, lng: point.lon));
      default:
    }
  }

  @override
  Widget build(BuildContext context) {
    final override = OverviewMap.debugMapBuilderOverride;
    if (override != null) return override(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.colors;
    return LayoutBuilder(
      builder: (context, constraints) {
        _viewport = constraints.biggest;
        final area = widget.area;
        return Stack(
          key: _mapKey,
          fit: StackFit.expand,
          children: [
            MapLibreMap(
              key: ValueKey(dark),
              options: MapOptions(
                initStyle: liveMapStyle(dark),
                initCenter: _initialCenter,
                initZoom: widget.restoreCamera?.zoom ?? _initialZoom,
                minZoom: kLiveMapMinZoom,
                maxZoom: kLiveMapMaxZoom,
                androidTextureMode: true,
                androidMode: AndroidPlatformViewMode.tlhc_vd,
              ),
              // The map lives inside the tab swipe: it must win horizontal
              // drags, or panning it would change the tab.
              gestureRecognizers: {
                Factory<OneSequenceGestureRecognizer>(
                  EagerGestureRecognizer.new,
                ),
              },
              onMapCreated: (c) {
                _detach();
                _controller = c;
              },
              onStyleLoaded: _onStyleLoaded,
              onEvent: _onEvent,
              children: [
                if (area != null && widget.onPinMoved != null)
                  OverviewPin(
                    pin: area.pin,
                    mapKey: _mapKey,
                    onMoved: widget.onPinMoved!,
                  ),
              ],
            ),
            // The terrain colour covers the map until the style has loaded and
            // the camera is placed, then fades out.
            IgnorePointer(
              child: AnimatedOpacity(
                opacity: _styleReady ? 0 : 1,
                duration: const Duration(milliseconds: 350),
                child: ColoredBox(color: colors.mapTerrain),
              ),
            ),
            if (widget.showAttribution)
              Positioned(
                left: kMapAttributionInset,
                bottom: kMapAttributionInset,
                child: MapAttribution(onOpen: openMapCopyright),
              ),
          ],
        );
      },
    );
  }

  Geographic get _initialCenter {
    final restore = widget.restoreCamera;
    if (restore != null) {
      return Geographic(lon: restore.center.lng, lat: restore.center.lat);
    }
    final box = widget.bounds;
    return box == null
        ? Geographic(lon: 0, lat: 0)
        : Geographic(
            lon: (box.west + box.east) / 2,
            lat: (box.south + box.north) / 2,
          );
  }

  double get _initialZoom => widget.bounds == null ? 2 : 10;
}
