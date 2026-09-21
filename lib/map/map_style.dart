/// The MapTiler basemap, and the single source of truth for it: the preview
/// renderer fetches these ids as raster tiles and `MapConfig.vectorStyleUrl`
/// builds the live map's vector style from the same id, so a ride's cached
/// preview looks like the map shown on the ride / detail screen. topo-v2, with
/// basic-v2-dark for dark mode (topo has no dark twin).
abstract final class MapStyle {
  static String mapId(bool dark) => dark ? 'basic-v2-dark' : 'topo-v2';
}
