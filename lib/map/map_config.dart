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
}
