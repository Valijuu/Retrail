import 'dart:math' as math;

import 'sim_route.dart';

/// A GPS error model: per run, a fresh source of per-fix errors.
class NoiseModel {
  const NoiseModel(
    this.name,
    this._source, {
    required this.runs,
    required this.maxFailureShare,
    this.isStress = false,
  });

  final String name;

  /// Seeded runs per scenario.
  final int runs;

  /// The share of runs allowed to fail a scenario (the threshold).
  final double maxFailureShare;

  /// A stress model: its threshold is looser, and each scenario may not fail
  /// more runs than its committed baseline plus [stressRatchetSlack].
  final bool isStress;
  final Xy Function() Function(math.Random) _source;

  /// Failing runs allowed by the share alone.
  int get maxFailures => (maxFailureShare * runs).floor();

  Xy Function() start(math.Random r) => _source(r);
}

double _gauss(math.Random r) {
  final u = 1 - r.nextDouble();
  return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * r.nextDouble());
}

Xy Function() _none(math.Random _) =>
    () => (n: 0, e: 0);

Xy Function() Function(math.Random) _uniform(double halfM) =>
    (r) =>
        () => (
          n: (2 * r.nextDouble() - 1) * halfM,
          e: (2 * r.nextDouble() - 1) * halfM,
        );

Xy Function() Function(math.Random) _gaussian(double sigmaM) =>
    (r) =>
        () => (n: _gauss(r) * sigmaM, e: _gauss(r) * sigmaM);

/// GPS drift: per axis x ← ρ·x + N(0, σ), started in its stationary spread
/// σ/√(1 − ρ²) (≈ 6.9 m for σ 3, ρ 0.9).
Xy Function() Function(math.Random) _walk(double sigmaM, double rho) => (r) {
  final spread = sigmaM / math.sqrt(1 - rho * rho);
  var n = _gauss(r) * spread, e = _gauss(r) * spread;
  return () {
    n = rho * n + _gauss(r) * sigmaM;
    e = rho * e + _gauss(r) * sigmaM;
    return (n: n, e: e);
  };
};

/// Stress runs may fail this many more than the committed baseline.
const stressRatchetSlack = 3;

/// The long-term target for the stress model (now [NoiseModel.maxFailureShare]
/// is 15 %, a ratchet from the baseline down to this).
const stressTargetShare = 0.05;

const noiseless = NoiseModel('noiseless', _none, runs: 200, maxFailureShare: 0);

/// Gate models must pass; the stress model is ratcheted (see [isStress]).
final noiseModels = [
  noiseless,
  NoiseModel('uniform ±5 m', _uniform(5), runs: 200, maxFailureShare: 0.02),
  NoiseModel('gaussian σ5', _gaussian(5), runs: 200, maxFailureShare: 0.05),
  NoiseModel(
    'gaussian σ8',
    _gaussian(8),
    runs: 100,
    maxFailureShare: 0.15,
    isStress: true,
  ),
  NoiseModel(
    'correlated walk σ3 ρ0.9',
    _walk(3, 0.9),
    runs: 200,
    maxFailureShare: 0.02,
  ),
];
