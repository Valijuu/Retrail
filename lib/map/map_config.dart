/// Map-wide links (the map credit's copyright pages).
abstract final class MapConfig {
  /// Copyright pages the map credits link to (`MapAttribution`).
  static final Uri openMapTilesCopyright = Uri.parse(
    'https://openmaptiles.org/',
  );
  static final Uri osmCopyright = Uri.parse(
    'https://www.openstreetmap.org/copyright',
  );
}
