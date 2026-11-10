import '../../data/db/app_database.dart' show RideOutlineRow;
import '../../domain/ride_outline.dart';

/// One cached ride outline: its stored row, decoded on first use, with the
/// map fragments built from it (see `overview_geojson.dart`).
class OutlineEntry {
  OutlineEntry(this.row);

  final RideOutlineRow row;
  RideOutline? _decoded;

  /// GeoJSON line coordinates of this ride, built once.
  String? lineFragment;

  /// GeoJSON heat coordinates of this ride, built once.
  String? heatFragment;

  /// A route that gave no outline (fewer than two points) is stored empty.
  bool get isEmpty => row.polyline.isEmpty;

  OutlineBounds get bounds =>
      (south: row.south, west: row.west, north: row.north, east: row.east);

  RideOutline get outline => _decoded ??= RideOutline.decode(row.polyline);
}

/// In-memory outlines by ride id (#96). Rows are read once; decoding and the
/// map fragments are lazy, and only changed or removed rides are touched.
class OutlineCache {
  final Map<int, OutlineEntry> _entries = {};

  OutlineEntry? operator [](int rideId) => _entries[rideId];

  /// Adds [rows]. An unchanged row keeps its entry (and fragments); a
  /// changed one replaces it.
  void addRows(Iterable<RideOutlineRow> rows) {
    for (final row in rows) {
      if (_entries[row.rideId]?.row != row) {
        _entries[row.rideId] = OutlineEntry(row);
      }
    }
  }

  /// Drops every cached ride that is not in [outlinedIds]: a deleted ride
  /// takes its outline and fragments with it.
  void sync(Set<int> outlinedIds) =>
      _entries.removeWhere((id, _) => !outlinedIds.contains(id));
}
