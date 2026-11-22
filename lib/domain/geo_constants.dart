import 'dart:math' as math;

/// Mean Earth radius in metres: the sphere of the shared Haversine distance.
const double earthRadiusM = 6371000;

/// [earthRadiusM] in kilometres.
const double earthRadiusKm = earthRadiusM / 1000;

/// Radians in one degree; multiply a degree value by it.
const double radiansPerDegree = math.pi / 180;

/// Degrees in one radian; multiply a radian value by it.
const double degreesPerRadian = 180 / math.pi;

/// Metres on the ground along one degree of latitude (or of longitude at the
/// equator) on the [earthRadiusM] sphere.
const double metresPerDegree = earthRadiusM * radiansPerDegree;
