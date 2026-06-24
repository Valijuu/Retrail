import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Gates the start of a ride. The real implementation (location permission +
/// GPS-on check) is device-specific and lands with Spec 5 Part B; until then
/// [AlwaysReadyGate] proceeds straight to the countdown. Interface seam → fakeable.
abstract interface class RideStartGate {
  Future<bool> ensureReady();
}

class AlwaysReadyGate implements RideStartGate {
  const AlwaysReadyGate();
  @override
  Future<bool> ensureReady() async => true;
}

final rideStartGateProvider =
    Provider<RideStartGate>((ref) => const AlwaysReadyGate());
