import 'package:flutter_test/flutter_test.dart';
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
}
