import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity_type.dart';

/// Which activity types the map shows (#96): `null` is every type, a set is
/// exactly those, the empty set none. The map keeps its own choice, apart
/// from the activity filter of the History list, so the rider's own activity
/// as the map's start and every tick in the activity menu leave the list as
/// it is.
class MapActivitiesNotifier extends Notifier<Set<ActivityType>?> {
  @override
  Set<ActivityType>? build() => null;

  void set(Set<ActivityType>? types) => state = types;
}

final mapActivitiesProvider =
    NotifierProvider<MapActivitiesNotifier, Set<ActivityType>?>(
      MapActivitiesNotifier.new,
    );

/// Whether [type] is shown under the selection [selected].
bool mapTypeShown(Set<ActivityType>? selected, ActivityType type) =>
    selected == null || selected.contains(type);

/// The selection after a tap on [tapped] in the activity menu. [present] are
/// the types the history has; ticking all of them again is "every type".
Set<ActivityType>? toggleMapType(
  Set<ActivityType>? selected,
  Set<ActivityType> present,
  ActivityType tapped,
) {
  final shown = {...(selected ?? present)};
  if (!shown.remove(tapped)) shown.add(tapped);
  return shown.containsAll(present) ? null : shown;
}

/// The selection after a tap on the "all" row: every type when some are off,
/// none when every type is on.
Set<ActivityType>? toggleAllMapTypes(
  Set<ActivityType>? selected,
  Set<ActivityType> present,
) {
  final allShown = selected == null || selected.containsAll(present);
  return allShown ? <ActivityType>{} : null;
}
