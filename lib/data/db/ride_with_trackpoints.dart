import 'app_database.dart';

/// In-memory pairing of a [Ride] with its [Trackpoint]s — the Drift equivalent
/// of the original Room `RideWithTrackpoint` `@Relation` (Drift has no
/// `@Relation`, so DAOs assemble this from a join).
class RideWithTrackpoints {
  const RideWithTrackpoints({required this.ride, required this.trackpoints});

  final Ride ride;
  final List<Trackpoint> trackpoints;
}
