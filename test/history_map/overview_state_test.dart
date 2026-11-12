import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/history/history_filter.dart';
import 'package:retrail/features/history/history_providers.dart';
import 'package:retrail/features/history_map/map_items.dart';
import 'package:retrail/features/history_map/history_map_providers.dart';

void main() {
  OverviewState state(List<String?> types) => OverviewState(
    mode: HistoryMapMode.lines,
    rideIds: const [1, 2],
    data: null,
    bounds: null,
    typeIds: types,
  );

  test('the same rides with another activity type are another state', () {
    expect(state(['SKI', 'LONGBOARD']), state(['SKI', 'LONGBOARD']));
    expect(
      state(['SKI', 'LONGBOARD']).hashCode,
      state(['SKI', 'LONGBOARD']).hashCode,
    );
    expect(state(['SKI', 'LONGBOARD']) == state(['SKI', 'SKI']), isFalse);
  });

  test('the map badge counts only the header filters the map uses', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    expect(c.read(activeMapFilterCountProvider), 0);
    c.read(historyFilterProvider.notifier)
      ..toggleActivity(ActivityType.ski)
      ..setSort(SortOrder.distance);
    expect(c.read(activeFilterCountProvider), 2);
    expect(c.read(activeMapFilterCountProvider), 0);
    c.read(historyFilterProvider.notifier).setFavoritesOnly(true);
    expect(c.read(activeMapFilterCountProvider), 1);
  });
}
