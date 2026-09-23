import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/db/ride_with_trackpoints.dart';
import 'package:retrail/domain/distance_calculator.dart';

Ride buildRide({
  int rideId = 1,
  String? description,
  String? typ,
  int? startTime,
  int? endTime,
  int? date,
  String? comment,
  bool isFavorite = false,
  int? favoritedAt,
  double? distanceMetres,
  int? durationMs,
  double? avgSpeedKmh,
  double? maxSpeedKmh,
  bool hasRoute = false,
}) =>
    Ride(
      rideId: rideId,
      description: description,
      typ: typ,
      startTime: startTime,
      endTime: endTime,
      date: date,
      comment: comment,
      isFavorite: isFavorite,
      favoritedAt: favoritedAt,
      distanceMetres: distanceMetres,
      durationMs: durationMs,
      avgSpeedKmh: avgSpeedKmh,
      maxSpeedKmh: maxSpeedKmh,
      hasRoute: hasRoute,
    );

int _tpId = 0;

Trackpoint buildTp({
  int rideId = 1,
  double latitude = 0,
  double longitude = 0,
  int timestamp = 0,
  double? speed,
}) =>
    Trackpoint(
      trackpointId: ++_tpId,
      rideId: rideId,
      latitude: latitude,
      longitude: longitude,
      timestamp: timestamp,
      speed: speed,
    );

RideWithTrackpoints rwt(Ride ride, List<Trackpoint> trackpoints) =>
    RideWithTrackpoints(ride: ride, trackpoints: trackpoints);

/// Returns a constant distance per segment, isolating stats math from geometry.
class FixedDistanceCalculator implements DistanceCalculator {
  const FixedDistanceCalculator(this.metres);
  final double metres;

  @override
  double distanceBetween(double lat1, double lon1, double lat2, double lon2) =>
      metres;
}
