import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/activity_type.dart';
import '../home/home_providers.dart' show lastActivityTypeProvider;
import 'history_map_providers.dart' show legendTypesProvider;
import 'map_activities.dart';

/// The rider's own activity (Settings, "Default activity") that the map last
/// narrowed itself to, so it does that once per choice and leaves a later
/// manual selection alone (#96).
class MapDefaultAppliedNotifier extends Notifier<ActivityType?> {
  @override
  ActivityType? build() => null;

  void set(ActivityType type) => state = type;
}

final mapDefaultAppliedProvider =
    NotifierProvider<MapDefaultAppliedNotifier, ActivityType?>(
      MapDefaultAppliedNotifier.new,
    );

/// Narrows the map to the rider's own activity when the map opens, and again
/// whenever that activity changes in Settings; between those moments every
/// tick in the activity menu is the rider's own. Needs the activity to occur
/// in the history, or the map would open empty.
void applyMapDefaultActivity(WidgetRef ref) {
  final own = ref.read(lastActivityTypeProvider).value;
  final present = ref.read(legendTypesProvider).value;
  if (own == null || present == null || !present.contains(own)) return;
  if (ref.read(mapDefaultAppliedProvider) == own) return;
  ref.read(mapDefaultAppliedProvider.notifier).set(own);
  // With one type in the history there is nothing to narrow.
  if (present.length < 2) return;
  ref.read(mapActivitiesProvider.notifier).set({own});
}
