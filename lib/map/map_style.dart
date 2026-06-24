/// MapTiler style ids used for both the live map and preview tiles.
abstract final class MapStyle {
  static String mapId(bool dark) => dark ? 'streets-v2-dark' : 'streets-v2';
}
