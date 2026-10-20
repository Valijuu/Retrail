import 'dart:math' as math;

/// Share of a route of [trackLengthM] metres that the ridden [intervals]
/// cover, from 0 to 1 (Spec 20): their union clipped to the route, so parts
/// ridden twice count once. [intervals] are in route metres, as
/// `FollowTracker.riddenIntervals` gives them. 0 for a route without length.
double followCoverage(List<(double, double)> intervals, double trackLengthM) {
  if (trackLengthM <= 0) return 0;
  final byStart = [...intervals]..sort((a, b) => a.$1.compareTo(b.$1));
  var riddenM = 0.0;
  var coveredToM = 0.0;
  for (final (fromM, toM) in byStart) {
    final startM = math.max(fromM, coveredToM);
    final endM = math.min(toM, trackLengthM);
    if (endM > startM) riddenM += endM - startM;
    coveredToM = math.max(coveredToM, endM);
  }
  return riddenM / trackLengthM;
}
