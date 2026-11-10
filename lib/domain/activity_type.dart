/// The kind of tracked ride. The [id] is the stable uppercase string persisted
/// in `Ride.typ` (e.g. "LONGBOARD") and never renamed. Declaration order is the
/// order of every picker. Labels and icons are UI concerns and live outside the
/// domain.
enum ActivityType {
  longboard('LONGBOARD'),
  skateboard('SKATEBOARD'),
  mountainboard('MOUNTAINBOARD'),
  rollerblades('ROLLERBLADES'),
  rollerskates('ROLLERSKATES'),
  scooter('SCOOTER'),
  snowboard('SNOWBOARD'),
  ski('SKI'),
  other('OTHER');

  const ActivityType(this.id);

  final String id;

  /// True for the winter types, where the descent is the figure riders compare.
  bool get isSnow => this == snowboard || this == ski;

  /// Maps a stored type string (`Ride.typ`) back to the enum, or null if none.
  static ActivityType? fromId(String? id) {
    return values.where((type) => type.id == id).firstOrNull;
  }

  /// Preselection for the first ride, before any "last used" exists.
  static const ActivityType defaultType = ActivityType.longboard;
}
