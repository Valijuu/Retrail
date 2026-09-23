import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart' show ThemeMode, WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../map/map_config.dart';
import '../../map/maptiler_tile_provider.dart';
import '../../map/preview_projection.dart';
import '../../map/preview_snapshot.dart';
import '../../map/route_preview_cache.dart';
import '../../tracking/tracking_providers.dart';
import '../shell/theme_mode_provider.dart';
import 'active_ride_controller.dart';
import 'preview_renderer.dart';

/// Resolves the brightness the app is *currently* showing, so a ride saved in
/// dark mode pre-generates the dark preview (system mode reads the platform).
ui.Brightness _resolveBrightness(ThemeMode mode) => switch (mode) {
      ThemeMode.light => ui.Brightness.light,
      ThemeMode.dark => ui.Brightness.dark,
      ThemeMode.system =>
        WidgetsBinding.instance.platformDispatcher.platformBrightness,
    };

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
  final cache = RoutePreviewCache(
    baseDir: dir,
    render: buildPreviewRenderer(
      isOnline: () => ref.read(isOnlineProvider).asData?.value ?? true,
      online: (points, brightness) => renderPreviewPng(
        points: points,
        widthDp: previewRenderWidthDp,
        heightDp: previewRenderHeightDp,
        pixelRatio: previewPixelRatio,
        tiles: tiles,
        brightness: brightness,
      ),
      offline: (points, brightness) => renderSketchPng(
        points: points,
        widthDp: previewRenderWidthDp,
        heightDp: previewRenderHeightDp,
        pixelRatio: previewPixelRatio,
        brightness: brightness,
      ),
    ),
  );
  ref.onDispose(cache.dispose);
  return cache;
});

/// Orchestrates the active-ride save/discard/stop/pause intents + preview.
final activeRideControllerProvider = Provider<ActiveRideController>(
  (ref) => ActiveRideController(
    ref.watch(rideTrackerProvider),
    ref.watch(routePreviewCacheProvider),
    currentBrightness: () => _resolveBrightness(
        ref.read(themeModeProvider).asData?.value ?? ThemeMode.system),
  ),
);
