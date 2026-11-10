import '../../domain/activity_type.dart';

/// Whether [type] is shown under the activity filter [selected]: an empty
/// filter shows every type.
bool legendTypeShown(Set<ActivityType> selected, ActivityType type) =>
    selected.isEmpty || selected.contains(type);

/// The activity filter after a tap on [tapped] in the map legend (#96).
/// [present] are the types the history has. Hiding works on the shared
/// filter: with every type shown, the filter becomes all present types but
/// [tapped]; a selection that would hide everything, or show everything,
/// becomes the empty filter.
Set<ActivityType> toggleLegendType(
  Set<ActivityType> selected,
  Set<ActivityType> present,
  ActivityType tapped,
) {
  final shown = selected.isEmpty ? {...present} : {...selected};
  if (!shown.remove(tapped)) shown.add(tapped);
  if (shown.isEmpty || shown.containsAll(present)) return {};
  return shown;
}
