/// The kind of tracked ride. The [id] is the stable uppercase string persisted
/// in `Ride.typ` (e.g. "LONGBOARD"). Label + icon are UI concerns wired in the
/// screen phases, not here.
enum ActivityType {
  longboard('LONGBOARD'),
  skateboard('SKATEBOARD'),
  rollerblades('ROLLERBLADES'),
  rollerskates('ROLLERSKATES'),
  mountainboard('MOUNTAINBOARD'),
  scooter('SCOOTER'),
  other('OTHER');

  const ActivityType(this.id);

  final String id;

  /// Maps a stored type string (`Ride.typ`) back to the enum, or null if none.
  static ActivityType? fromId(String? id) {
    if (id == null) return null;
    for (final type in values) {
      if (type.id == id) return type;
    }
    return null;
  }

  /// Preselection for the first ride, before any "last used" exists.
  static const ActivityType defaultType = ActivityType.longboard;
}
