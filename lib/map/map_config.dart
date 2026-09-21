import 'map_style.dart';

/// Map configuration. The MapTiler API key is supplied at build time via
/// `--dart-define=MAPTILER_KEY=…` (never committed). Reuse the existing key.
abstract final class MapConfig {
  static const String mapTilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');

  static bool get hasKey => mapTilerKey.isNotEmpty;

  /// MapLibre vector style document URL for the live map. The style id comes
  /// from [MapStyle] — the single source of truth shared with the preview
  /// renderer's raster tiles, so both stay on the same basemap.
  static String vectorStyleUrl(bool dark) =>
      'https://api.maptiler.com/maps/${MapStyle.mapId(dark)}/style.json?key=$mapTilerKey';
}
