import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../map/map_config.dart';
import '../../map/maptiler_tile_provider.dart';
import '../../map/preview_snapshot.dart';
import '../../map/route_preview_cache.dart';
import '../../tracking/tracking_providers.dart';
import 'active_ride_controller.dart';
import 'preview_renderer.dart';

// Render target for cached preview PNGs (history/home card size). Cached once
// per ride, so a fixed size is fine; History (Spec 13) renders at this aspect.
const _previewWidthDp = 320;
const _previewHeightDp = 200;
const _previewPixelRatio = 2.0;
const _previewBrightness = ui.Brightness.light;

/// App documents directory holding cached preview PNGs. Overridden in `main()`
/// with the awaited `getApplicationDocumentsDirectory()` (same pattern as
/// [preferencesRepositoryProvider]).
final previewCacheDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError(
      'previewCacheDirProvider must be overridden in main()'),
);

/// The single owner of the ride-preview disk cache. History/home consume this
/// same instance so previews are generated once and reused.
final routePreviewCacheProvider = Provider<RoutePreviewCache>((ref) {
  final dir = ref.watch(previewCacheDirProvider);
  final tiles = MapTilerTileProvider(apiKey: MapConfig.mapTilerKey);
  return RoutePreviewCache(
    baseDir: dir,
    render: buildPreviewRenderer(
      isOnline: () => ref.read(isOnlineProvider).asData?.value ?? true,
      online: (points) => renderPreviewPng(
        points: points,
        widthDp: _previewWidthDp,
        heightDp: _previewHeightDp,
        pixelRatio: _previewPixelRatio,
        tiles: tiles,
        brightness: _previewBrightness,
      ),
      offline: (points) => renderSketchPng(
        points: points,
        widthDp: _previewWidthDp,
        heightDp: _previewHeightDp,
        pixelRatio: _previewPixelRatio,
        brightness: _previewBrightness,
      ),
    ),
  );
});

/// Orchestrates the active-ride save/discard/stop/pause intents + preview.
final activeRideControllerProvider = Provider<ActiveRideController>(
  (ref) => ActiveRideController(
    ref.watch(rideTrackerProvider),
    ref.watch(routePreviewCacheProvider),
  ),
);
