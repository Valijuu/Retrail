import 'dart:io';

import 'package:flutter/material.dart';

import 'preview_projection.dart';
import 'route_preview_cache.dart';
import 'route_sketch.dart';

/// Shows a ride's cached preview PNG (generated once via [RoutePreviewCache]).
/// While generating — or when the ride has no route — it falls back to the
/// tile-free [RouteSketch], so list scrolling never blocks on tiles.
class RoutePreview extends StatefulWidget {
  const RoutePreview({
    super.key,
    required this.rideId,
    required this.points,
    required this.cache,
    this.cacheWidth,
  });

  final int rideId;
  final List<RoutePoint> points;
  final RoutePreviewCache cache;
  final int? cacheWidth;

  @override
  State<RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<RoutePreview> {
  Future<File>? _file;

  /// Set when the cache already knows the final PNG (synchronous fast path):
  /// the image builds on the FIRST frame — no sketch flash, no FutureBuilder
  /// rebuild — which is what keeps list scrolling smooth.
  File? _ready;
  Brightness? _brightness;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Resolve here (not initState) so the cached variant follows the current
    // theme; toggling light/dark re-runs this and regenerates the matching PNG.
    final brightness = Theme.of(context).brightness;
    if (brightness != _brightness) {
      _brightness = brightness;
      _maybeGenerate();
    }
  }

  @override
  void didUpdateWidget(RoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rideId != widget.rideId) _maybeGenerate();
  }

  void _maybeGenerate() {
    if (widget.points.isEmpty || _brightness == null) {
      _ready = null;
      _file = null;
      return;
    }
    _ready =
        widget.cache.resolvedFileFor(widget.rideId, brightness: _brightness!);
    _file = _ready != null
        ? null
        : widget.cache.ensurePreview(widget.rideId, widget.points,
            brightness: _brightness!);
  }

  Widget _image(File file) => Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
      );

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) return const RouteSketch(points: []);
    final ready = _ready;
    if (ready != null) return _image(ready);
    return FutureBuilder<File>(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _image(snapshot.data!);
        return RouteSketch(points: widget.points);
      },
    );
  }
}
