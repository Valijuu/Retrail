import '../../data/db/app_database.dart' show Ride;
import '../../domain/activity_type.dart';

/// The one elevation figure a History card shows (#97): the descent for
/// snowboard and ski, the ascent for everything else.
typedef CardElevation = ({bool isDescent, double metres});

/// The figure for [ride], or null when it has no elevation: a ride without
/// altitude data shows nothing, never `0 m`.
CardElevation? cardElevation(Ride ride) {
  final snow = ActivityType.fromId(ride.typ)?.isSnow ?? false;
  final metres = snow ? ride.descentM : ride.ascentM;
  return metres == null ? null : (isDescent: snow, metres: metres);
}
