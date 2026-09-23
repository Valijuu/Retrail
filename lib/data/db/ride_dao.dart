import 'package:drift/drift.dart';

import 'app_database.dart';
import 'ride_with_trackpoints.dart';
import 'tables.dart';

part 'ride_dao.g.dart';

/// Drift port of the original Room `RideDao`. Reactive reads return `Stream`s
/// (= Room `Flow`); mutations return `Future`s (= `suspend`).
@DriftAccessor(tables: [Rides, Trackpoints])
class RideDao extends DatabaseAccessor<AppDatabase> with _$RideDaoMixin {
  RideDao(super.db);

  Stream<List<Ride>> getAll() => select(rides).watch();

  Stream<List<Ride>> getAllByIds(List<int> rideIds) =>
      (select(rides)..where((r) => r.rideId.isIn(rideIds))).watch();

  Stream<Ride?> getById(int rideId) =>
      (select(rides)..where((r) => r.rideId.equals(rideId))).watchSingleOrNull();

  Stream<List<RideWithTrackpoints>> getAllRidesWithTrackpoints() =>
      _joinedRides().watch().map(_group);

  Stream<RideWithTrackpoints?> getRideWithTrackpointsById(int rideId) {
    final query = _joinedRides()..where(rides.rideId.equals(rideId));
    return query.watch().map((rows) {
      final grouped = _group(rows);
      return grouped.isEmpty ? null : grouped.first;
    });
  }

  Stream<List<RideWithTrackpoints>> getRidesWithTrackpointsBetween(
      int weekStartMs, int weekEndMs) {
    final query = _joinedRides()
      ..where(rides.startTime.isBetweenValues(weekStartMs, weekEndMs));
    return query.watch().map(_group);
  }

  // Uses coalesce(date, startTime) rather than startTime alone to replicate
  // the timestamp fallback the History feature uses in Dart
  // (`ride.date ?? ride.startTime ?? 0`, history_items.dart).
  //
  // Rides only — no trackpoints join. The History list used to join every
  // visible ride's full trackpoint list here, re-fetching/re-parsing it on
  // every write to either table (issue #21). Stats are denormalized (see
  // updateStats) and hasRoute tells the list whether a card has a preview to
  // show; the actual points are fetched lazily, per card, only for a preview
  // that isn't cached yet (see HistoryRideCard/_Thumbnail).
  Stream<List<Ride>> getRidesInRange({int? startMs, int? endMs}) {
    final query = select(rides);
    if (startMs != null || endMs != null) {
      final ts = coalesce([rides.date, rides.startTime]);
      if (startMs != null) query.where((_) => ts.isBiggerOrEqualValue(startMs));
      if (endMs != null) query.where((_) => ts.isSmallerOrEqualValue(endMs));
    }
    return query.watch();
  }

  JoinedSelectStatement<HasResultSet, dynamic> _joinedRides() {
    return select(rides).join([
      leftOuterJoin(trackpoints, trackpoints.rideId.equalsExp(rides.rideId)),
    ]);
  }

  List<RideWithTrackpoints> _group(List<TypedResult> rows) {
    // LinkedHashMap preserves first-seen ride order (matches Room's rowid order).
    final ordered = <int, (Ride, List<Trackpoint>)>{};
    for (final row in rows) {
      final ride = row.readTable(rides);
      final tp = row.readTableOrNull(trackpoints);
      final entry = ordered.putIfAbsent(ride.rideId, () => (ride, <Trackpoint>[]));
      if (tp != null) entry.$2.add(tp);
    }
    return ordered.values
        .map((e) => RideWithTrackpoints(ride: e.$1, trackpoints: e.$2))
        .toList();
  }

  Future<int> insert(RidesCompanion ride) =>
      into(rides).insertOnConflictUpdate(ride);

  Future<List<int>> insertAll(List<RidesCompanion> rideList) {
    return transaction(() async {
      final ids = <int>[];
      for (final c in rideList) {
        ids.add(await into(rides).insertOnConflictUpdate(c));
      }
      return ids;
    });
  }

  /// Rides whose row was opened but never stamped with an end time.
  Future<List<Ride>> getUnfinished() =>
      (select(rides)..where((r) => r.endTime.isNull())).get();

  Future<void> updateEndTime(int rideId, int endTime) =>
      (update(rides)..where((r) => r.rideId.equals(rideId)))
          .write(RidesCompanion(endTime: Value(endTime)));

  /// Writes the denormalized [RideStats] fields + [hasRoute] (see tables.dart)
  /// computed once at ride finalization, so History never recomputes them
  /// from raw trackpoints on every list rebuild.
  Future<void> updateStats(
    int rideId, {
    required double distanceMetres,
    required int durationMs,
    required double avgSpeedKmh,
    required double maxSpeedKmh,
    required bool hasRoute,
  }) =>
      (update(rides)..where((r) => r.rideId.equals(rideId))).write(RidesCompanion(
        distanceMetres: Value(distanceMetres),
        durationMs: Value(durationMs),
        avgSpeedKmh: Value(avgSpeedKmh),
        maxSpeedKmh: Value(maxSpeedKmh),
        hasRoute: Value(hasRoute),
      ));

  Future<void> updateRideDetails(int rideId, String? description, String? comment) =>
      (update(rides)..where((r) => r.rideId.equals(rideId))).write(
          RidesCompanion(description: Value(description), comment: Value(comment)));

  Future<void> updateRideType(int rideId, String? typ) =>
      (update(rides)..where((r) => r.rideId.equals(rideId)))
          .write(RidesCompanion(typ: Value(typ)));

  Future<void> updateFavorite(int rideId, bool isFavorite, int? favoritedAt) =>
      (update(rides)..where((r) => r.rideId.equals(rideId))).write(RidesCompanion(
          isFavorite: Value(isFavorite), favoritedAt: Value(favoritedAt)));

  Stream<List<Ride>> getFavoriteRides() => (select(rides)
        ..where((r) => r.isFavorite.equals(true))
        ..orderBy(
            [(r) => OrderingTerm(expression: r.startTime, mode: OrderingMode.desc)]))
      .watch();

  Stream<List<Ride>> getFilteredFavoriteRides(
      {int startTime = 0, String sortBy = 'date'}) {
    final query = select(rides)..where((r) => r.isFavorite.equals(true));
    if (startTime != 0) {
      query.where((r) => r.startTime.isBiggerOrEqualValue(startTime));
    }
    _applySort(query, sortBy);
    return query.watch();
  }

  Stream<List<Ride>> getFilteredRides(
      {int startTime = 0, String sortBy = 'date', String searchQuery = ''}) {
    final query = select(rides);
    if (startTime != 0) {
      query.where((r) => r.startTime.isBiggerOrEqualValue(startTime));
    }
    if (searchQuery.isNotEmpty) {
      final like = '%$searchQuery%';
      query.where((r) => r.description.like(like) | r.comment.like(like));
    }
    _applySort(query, sortBy);
    return query.watch();
  }

  // Mirrors the original ORDER BY: 'duration' sorts by (endTime - startTime) ASC,
  // any other value (incl. 'date') falls back to startTime DESC. distance/speed
  // are not SQL-sortable (computed from trackpoints); the ViewModel re-sorts those.
  void _applySort(SimpleSelectStatement<$RidesTable, Ride> query, String sortBy) {
    if (sortBy == 'duration') {
      query.orderBy([
        (r) => OrderingTerm(
            expression: r.endTime - r.startTime, mode: OrderingMode.asc),
        (r) => OrderingTerm(expression: r.startTime, mode: OrderingMode.desc),
      ]);
    } else {
      query.orderBy(
          [(r) => OrderingTerm(expression: r.startTime, mode: OrderingMode.desc)]);
    }
  }

  // Named `deleteRide` to avoid clashing with Drift's `delete(table)` builder.
  Future<void> deleteRide(Ride ride) => delete(rides).delete(ride);

  Future<void> deleteById(int rideId) =>
      (delete(rides)..where((r) => r.rideId.equals(rideId))).go();

  Future<void> deleteByIds(List<int> rideIds) =>
      (delete(rides)..where((r) => r.rideId.isIn(rideIds))).go();
}
