import '../../domain/activity_type.dart';

/// Whether [type] is shown under the activity filter [selected]: an empty
/// filter shows every type.
bool legendTypeShown(Set<ActivityType> selected, ActivityType type) =>
    selected.isEmpty || selected.contains(type);

/// Whether [type] is the only type shown, so the menu locks its checkbox:
/// one type always stays on, otherwise the empty filter would flip
/// everything back on at once.
bool legendTypeLocked(
  Set<ActivityType> selected,
  Set<ActivityType> present,
  ActivityType type,
) {
  final shown = selected.isEmpty ? present : selected;
  return shown.length == 1 && shown.contains(type);
}

/// The activity filter after a tap on [tapped] in the activity menu (#96).
/// [present] are the types the history has. Hiding works on the shared
/// filter: with every type shown, the filter becomes all present types but
/// [tapped]; a selection that shows every present type becomes the empty
/// filter. The last shown type stays as it is (see [legendTypeLocked]).
Set<ActivityType> toggleLegendType(
  Set<ActivityType> selected,
  Set<ActivityType> present,
  ActivityType tapped,
) {
  if (legendTypeLocked(selected, present, tapped)) return selected;
  final shown = selected.isEmpty ? {...present} : {...selected};
  if (!shown.remove(tapped)) shown.add(tapped);
  if (shown.containsAll(present)) return {};
  return shown;
}

/// The activity filter after a tap on the "all" row of the activity menu:
/// with every present type shown it narrows to the first present type (one
/// always stays on, see [legendTypeLocked]); otherwise it shows every type.
Set<ActivityType> toggleAllLegendTypes(
  Set<ActivityType> selected,
  Set<ActivityType> present,
) {
  final allShown = selected.isEmpty || selected.containsAll(present);
  if (!allShown) return {};
  if (present.length < 2) return {};
  return {ActivityType.values.firstWhere(present.contains)};
}
