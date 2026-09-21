import '../domain/activity_type.dart';
import 'location_fix.dart';

/// A point on the live route (latitude, longitude).
typedef RoutePoint = ({double lat, double lng});

/// Immutable snapshot of all live ride-recording state. Replaces the original
/// app's eight separate `StateFlow`s with one object (the UI selects per field).
class RideTrackingState {
  const RideTrackingState({
    this.location,
    this.isTracking = false,
    this.trackPoints = const [],
    this.distanceMetres = 0.0,
    this.speedKmh,
    this.maxSpeedKmh = 0.0,
    this.elapsedSeconds = 0,
    this.isPaused = false,
    this.activityType,
  });

  final LocationFix? location;
  final bool isTracking;
  final List<RoutePoint> trackPoints;
  final double distanceMetres;
  final double? speedKmh;

  /// Top speed reached during the current ride. Owned by the tracker (not the
  /// screen) so it survives the active-ride screen being disposed and recreated
  /// mid-ride.
  final double maxSpeedKmh;
  final int elapsedSeconds;
  final bool isPaused;
  final ActivityType? activityType;
}
