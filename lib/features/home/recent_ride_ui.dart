import '../../data/db/ride_with_trackpoints.dart';
import '../../domain/distance_calculator.dart';
import '../../domain/formatters.dart';
import '../../domain/ride_stats.dart';
import '../../domain/ride_title.dart';

/// UI model for a recent-rides / favorites card. Mirrors the original
/// `RecentRideUi`.
class RecentRideUi {
  const RecentRideUi({
    required this.rideId,
    required this.title,
    required this.dateTime,
    required this.distanceKm,
    required this.hasRoute,
    this.startLat,
    this.startLng,
  });

  final int rideId;
  final String title;
  final String dateTime;
  final double distanceKm;
  final bool hasRoute;
  final double? startLat;
  final double? startLng;

  static RecentRideUi from(RideWithTrackpoints rwt, DistanceCalculator calc,
      {String? locale}) {
    final stats = computeRideStats(rwt, calc);
    final start = rwt.trackpoints.isNotEmpty ? rwt.trackpoints.first : null;
    return RecentRideUi(
      rideId: rwt.ride.rideId,
      title: rideDisplayTitle(rwt.ride, locale: locale),
      dateTime: formatRideDate(rwt.ride.date, locale: locale),
      distanceKm: stats.distanceMetres / 1000.0,
      hasRoute: rwt.trackpoints.isNotEmpty,
      startLat: start?.latitude,
      startLng: start?.longitude,
    );
  }
}
