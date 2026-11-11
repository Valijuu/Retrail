import 'package:flutter/material.dart';
import 'package:maplibre/maplibre.dart';

import '../domain/heading.dart' show LatLng;

/// Size of the pin marker.
const Size kOverviewPinSize = Size(40, 48);

/// The grab handle of the area pin on the overview map. The pin itself is
/// drawn by the map (a symbol layer, see `addOverviewLayers`), because a
/// widget on top of the map trails the camera and trembles while it moves;
/// this widget is invisible and only catches the drag. [onDragged] reports
/// the point under the finger while dragging (null when the drag ends),
/// [onMoved] where it was dropped. [mapKey] is the key of the widget that
/// holds the map, to turn the finger position into a map position.
class OverviewPin extends StatefulWidget {
  const OverviewPin({
    super.key,
    required this.pin,
    required this.mapKey,
    required this.onMoved,
    required this.onDragged,
  });

  final LatLng pin;
  final GlobalKey mapKey;
  final ValueChanged<LatLng> onMoved;
  final ValueChanged<LatLng?> onDragged;

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
              if (p == null) return;
              setState(() => _dragged = p);
              widget.onDragged(p);
            },
            onPanCancel: () {
              setState(() => _dragged = null);
              widget.onDragged(null);
            },
            onPanEnd: (_) {
              final p = _dragged;
              setState(() => _dragged = null);
              // The map keeps drawing the dragged point until the new pin
              // arrives, so it does not flash back to the old one.
              if (p != null) widget.onMoved(p);
            },
            // Invisible but still catches touches (Opacity keeps hit-testing).
            child: const Opacity(
              opacity: 0,
              child: Icon(Icons.location_on, size: 48),
            ),
          ),
        ),
      ],
    );
  }
}
