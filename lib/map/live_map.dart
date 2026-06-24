import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/theme/app_colors.dart';
import 'map_config.dart';
import 'preview_projection.dart';

/// Live/active-ride map (`flutter_map`): MapTiler raster basemap with the
/// halo + blue route polyline drawn on Flutter's canvas, plus start/end and
/// current-position markers. Camera follows the current position.
///
/// Heading-up rotation and follow smoothness are tuned/verified on-device
/// (Spec 5 Part B); this builds the widget and renders a static route.
class LiveMap extends StatefulWidget {
  const LiveMap({
    super.key,
    required this.points,
    this.current,
    this.initialZoom = 16.5,
  });

  final List<RoutePoint> points;
  final RoutePoint? current;
  final double initialZoom;

  @override
  State<LiveMap> createState() => _LiveMapState();
}

class _LiveMapState extends State<LiveMap> {
  final MapController _controller = MapController();

  LatLng get _center {
    final c = widget.current ??
        (widget.points.isNotEmpty ? widget.points.last : null);
    return c != null ? LatLng(c.lat, c.lng) : const LatLng(0, 0);
  }

  @override
  void didUpdateWidget(LiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.current != null && widget.current != oldWidget.current) {
      _controller.move(_center, _controller.camera.zoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final route = [for (final p in widget.points) LatLng(p.lat, p.lng)];

    return FlutterMap(
      mapController: _controller,
      options: MapOptions(initialCenter: _center, initialZoom: widget.initialZoom),
      children: [
        TileLayer(
          urlTemplate: MapConfig.rasterUrlTemplate(dark),
          userAgentPackageName: 'com.retrail.retrail',
        ),
        if (route.length >= 2)
          PolylineLayer(
            polylines: [
              Polyline(points: route, strokeWidth: 8, color: colors.routeLineHalo),
              Polyline(points: route, strokeWidth: 4.5, color: colors.routeLineBlue),
            ],
          ),
        MarkerLayer(
          markers: [
            if (widget.points.isNotEmpty)
              _dot(widget.points.first, colors.markerStartGreen),
            if (widget.points.length >= 2)
              _dot(widget.points.last, colors.markerEndRed),
            if (widget.current != null)
              _dot(widget.current!, colors.routeLineBlue, ring: true),
          ],
        ),
      ],
    );
  }

  Marker _dot(RoutePoint p, Color color, {bool ring = false}) => Marker(
        point: LatLng(p.lat, p.lng),
        width: 18,
        height: 18,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: ring ? Border.all(color: Colors.white, width: 3) : null,
          ),
        ),
      );
}
