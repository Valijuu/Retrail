/// MapTiler style ids used for the preview raster tiles. **Must match the live
/// map's vector style** (`MapConfig.vectorStyleId`) so a ride's cached preview
/// looks like the map shown on the ride / detail screen: topo-v2, with
/// basic-v2-dark for dark mode (topo has no dark twin).
abstract final class MapStyle {
  static String mapId(bool dark) => dark ? 'basic-v2-dark' : 'topo-v2';
}
