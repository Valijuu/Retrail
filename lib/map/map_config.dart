/// Map configuration. The MapTiler API key is supplied at build time via
/// `--dart-define=MAPTILER_KEY=…` (never committed). Reuse the existing key.
abstract final class MapConfig {
  static const String mapTilerKey =
      String.fromEnvironment('MAPTILER_KEY', defaultValue: '');

  static bool get hasKey => mapTilerKey.isNotEmpty;

  /// Raster tile URL template for the live map's `TileLayer`.
  static String rasterUrlTemplate(bool dark) =>
      'https://api.maptiler.com/maps/${dark ? 'streets-v2-dark' : 'streets-v2'}'
      '/{z}/{x}/{y}.png?key=$mapTilerKey';

  /// Vector style id for the live map. topo-v2 has no dark twin, so dark mode
  /// pairs with the lighter basic-v2-dark (both verified smooth on-device).
  static String vectorStyleId(bool dark) => dark ? 'basic-v2-dark' : 'topo-v2';

  /// MapLibre vector style document URL for the live map.
  static String vectorStyleUrl(bool dark) =>
      'https://api.maptiler.com/maps/${vectorStyleId(dark)}/style.json?key=$mapTilerKey';
}
