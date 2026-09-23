import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'preview_projection.dart';
import 'route_preview_cache.dart';
import 'route_sketch.dart';

/// Shows a ride's cached preview PNG (generated once via [RoutePreviewCache]).
/// While generating — or when the ride has no route — it falls back to the
/// tile-free [RouteSketch], so list scrolling never blocks on tiles.
///
/// Takes [hasRoute] + a lazy [pointsLoader] rather than an eager point list:
/// the cache-hit fast path ([RoutePreviewCache.resolvedFileFor]) never needs
/// the actual coordinates, so a caller backed by a rides-only list query
/// (see issue #21) isn't forced to have every ride's trackpoints on hand
/// just to check whether a preview is already cached.
class RoutePreview extends StatefulWidget {
  const RoutePreview({
    super.key,
    required this.rideId,
    required this.hasRoute,
    required this.pointsLoader,
    required this.cache,
    this.cacheWidth,
  });

  final int rideId;
  final bool hasRoute;
  final Future<List<RoutePoint>> Function() pointsLoader;
  final RoutePreviewCache cache;
  final int? cacheWidth;

  @override
  State<RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<RoutePreview> {
  Future<File>? _file;

  /// Set when the cache already knows the final PNG (synchronous fast path):
  /// the image builds on the FIRST frame — no sketch flash, no FutureBuilder
  /// rebuild — which is what keeps list scrolling smooth. Never needs
  /// [widget.pointsLoader] — that's only called below it, on a real miss.
  File? _ready;
  Brightness? _brightness;
  StreamSubscription<int>? _upgradeSub;

  @override
  void initState() {
    super.initState();
    _listenForUpgrades();
  }

  /// A stale preview of this ride was just re-rendered complete: drop the old
  /// decoded frame (same file path, so the ImageCache would keep serving it)
  /// and re-resolve onto the synchronous fast path.
  void _listenForUpgrades() {
    _upgradeSub?.cancel();
    _upgradeSub = widget.cache.upgrades
        .where((id) => id == widget.rideId)
        .listen((_) {
      final file = _ready ?? widget.cache.resolvedFileFor(widget.rideId,
          brightness: _brightness ?? Brightness.light);
      if (file != null) {
        FileImage(file).evict();
        if (widget.cacheWidth != null) {
          ResizeImage(FileImage(file), width: widget.cacheWidth).evict();
        }
      }
      if (mounted) setState(_maybeGenerate);
    });
  }

  @override
  void dispose() {
    _upgradeSub?.cancel();
    super.dispose();
  }

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
    if (oldWidget.cache != widget.cache) _listenForUpgrades();
    if (oldWidget.rideId != widget.rideId) _maybeGenerate();
  }

  void _maybeGenerate() {
    if (!widget.hasRoute || _brightness == null) {
      _ready = null;
      _file = null;
      return;
    }
    _ready =
        widget.cache.resolvedFileFor(widget.rideId, brightness: _brightness!);
    _file = _ready != null
        ? null
        : widget.pointsLoader().then((points) => widget.cache
            .ensurePreview(widget.rideId, points, brightness: _brightness!));
  }

  Widget _image(File file) => Image.file(
        file,
        fit: BoxFit.cover,
        cacheWidth: widget.cacheWidth,
        gaplessPlayback: true,
      );

  @override
  Widget build(BuildContext context) {
    if (!widget.hasRoute) return const RouteSketch(points: []);
    final ready = _ready;
    if (ready != null) return _image(ready);
    return FutureBuilder<File>(
      future: _file,
      builder: (context, snapshot) {
        if (snapshot.hasData) return _image(snapshot.data!);
        // Loading (points not fetched yet) or mid-render — same flat
        // fallback either way; the real shape only exists once points load.
        return const RouteSketch(points: []);
      },
    );
  }
}
