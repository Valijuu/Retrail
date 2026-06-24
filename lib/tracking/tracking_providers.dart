import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/data_providers.dart';
import '../domain/distance_calculator.dart';
import 'ride_tracker.dart';
import 'ride_tracking_state.dart';

final distanceCalculatorProvider =
    Provider<DistanceCalculator>((ref) => const HaversineDistanceCalculator());

/// Process-lifetime ride recorder.
final rideTrackerProvider = Provider<RideTracker>((ref) {
  final tracker = RideTracker(
    ref.read(rideRepositoryProvider),
    ref.read(trackpointRepositoryProvider),
    ref.read(distanceCalculatorProvider),
  );
  ref.onDispose(tracker.dispose);
  return tracker;
});

/// Live tracking state — seeded from the tracker's current snapshot (the
/// `changes` stream does not replay), then following its updates.
final rideTrackingStateProvider = StreamProvider<RideTrackingState>((ref) async* {
  final tracker = ref.watch(rideTrackerProvider);
  yield tracker.state;
  yield* tracker.changes;
});

/// Whether a ride is currently being recorded.
final isTrackingProvider = Provider<bool>(
  (ref) => ref.watch(rideTrackingStateProvider).asData?.value.isTracking ?? false,
);
