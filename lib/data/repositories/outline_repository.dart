import 'dart:isolate';

import 'package:drift/drift.dart' show Value;

import '../../domain/heading.dart' show LatLng;
import '../../domain/ride_outline.dart';
import '../db/app_database.dart';
import '../db/outline_dao.dart';
import '../db/trackpoint_dao.dart';

/// Stores and fills the ride outlines the History map draws (#96, ADR 0001).
class OutlineRepository {
  OutlineRepository(this._outlines, this._trackpoints);

  final OutlineDao _outlines;
  final TrackpointDao _trackpoints;

  /// The ids of the rides that have an outline row (see
  /// [OutlineDao.watchOutlinedRideIds]).
  Stream<Set<int>> watchOutlinedRideIds() => _outlines.watchOutlinedRideIds();

  /// The stored outlines of [rideIds].
  Future<List<RideOutlineRow>> load(Iterable<int> rideIds) =>
      _outlines.getByRideIds(rideIds);

  /// Simplifies [points] and stores them as the outline of [rideId]. Fewer
  /// than two points store nothing; a ride that is gone is ignored.
  Future<void> save(int rideId, List<LatLng> points) async {
    final outline = await Isolate.run(() => RideOutline.simplify(points));
    await _write(rideId, outline);
  }

  /// Fills the outline of the oldest ride that has none, reading its
  /// trackpoints in one query. Returns whether another ride was still waiting
  /// when this one finished. [afterRead] runs between reading and writing
  /// (a seam for the "deleted meanwhile" case).
  Future<bool> fillNext({Future<void> Function()? afterRead}) async {
    final pending = await _outlines.rideIdsWithoutOutline();
    if (pending.isEmpty) return false;
    final rideId = pending.first;
    final rows = await _trackpoints.getByRideId(rideId).first;
    final points = [
      for (final tp in rows) (lat: tp.latitude, lng: tp.longitude),
    ];
    await afterRead?.call();
    final outline = await Isolate.run(() => RideOutline.simplify(points));
    if (outline.points.isEmpty) {
      // A route that gives no outline must not be picked again and again.
      await _write(rideId, const RideOutline([]), emptyMarker: true);
    } else {
      await _write(rideId, outline);
    }
    return pending.length > 1;
  }

  Future<void> _write(
    int rideId,
    RideOutline outline, {
    bool emptyMarker = false,
  }) async {
    final box = outline.bounds;
    if (box == null && !emptyMarker) return;
    await _outlines.upsert(
      RideOutlinesCompanion.insert(
        rideId: Value(rideId),
        polyline: outline.encode(),
        south: box?.south ?? 0,
        west: box?.west ?? 0,
        north: box?.north ?? 0,
        east: box?.east ?? 0,
      ),
    );
  }
}
