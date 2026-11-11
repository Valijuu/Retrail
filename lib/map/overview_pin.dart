import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../core/theme/theme_context.dart';
import '../domain/heading.dart' show LatLng;

/// Size of the pin marker.
const Size kOverviewPinSize = Size(40, 48);

/// The area pin on the overview map: a marker widget the rider can drag. The
/// geographic point follows the finger; [onMoved] reports where it was
/// dropped. [mapKey] is the key of the widget that holds the map, to turn the
/// finger position into a map position.
class OverviewPin extends StatefulWidget {
  const OverviewPin({
    super.key,
    required this.pin,
    required this.mapKey,
    required this.onMoved,
  });

  final LatLng pin;
  final GlobalKey mapKey;
  final ValueChanged<LatLng> onMoved;

  @override
  State<OverviewPin> createState() => _OverviewPinState();
}

class _OverviewPinState extends State<OverviewPin> {
  LatLng? _dragged;

  LatLng get _shown => _dragged ?? widget.pin;

  LatLng? _under(Offset global, MapController controller) {
    final box = widget.mapKey.currentContext?.findRenderObject();
    if (box is! RenderBox) return null;
    // The pin's tip sits at its bottom edge, below the finger.
    final local =
        box.globalToLocal(global) + Offset(0, kOverviewPinSize.height / 2);
    final geo = controller.toLngLat(local);
    return (lat: geo.lat, lng: geo.lon);
  }

  @override
  Widget build(BuildContext context) {
    final controller = MapController.maybeOf(context);
    if (controller == null) return const SizedBox.shrink();
    final colors = context.colors;
    return WidgetLayer(
      allowInteraction: true,
      markers: [
        Marker(
          point: Geographic(lon: _shown.lng, lat: _shown.lat),
          size: kOverviewPinSize,
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanUpdate: (d) {
              final p = _under(d.globalPosition, controller);
              if (p != null) setState(() => _dragged = p);
            },
            onPanCancel: () => setState(() => _dragged = null),
            onPanEnd: (_) {
              final p = _dragged;
              setState(() => _dragged = null);
              if (p != null) widget.onMoved(p);
            },
            child: Icon(
              Icons.location_on,
              size: kOverviewPinSize.height,
              color: colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
