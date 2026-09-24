import 'dart:math' as math;

import '../domain/activity_type.dart';
import 'repositories/ride_repository.dart';
import 'repositories/trackpoint_repository.dart';

/// Debug-only sample rides: 15 routes spanning near-stationary (a couple of
/// metres) up to cross-town (~19 km), across every [ActivityType], so the
/// read-only detail/fullscreen map's whole-route framing (see
/// `LiveMap._initialCamera`) can be checked against a real spread of
/// bounding-box sizes and marker types.
///
/// The rides are also spread over time (see [_SeedPeriod]) with differing
/// paces, so Home's day/week/year stat switch shows three distinct sets of
/// km / Ø km/h / ride count / duration, and History's year/month filters
/// have more than one year and month to work with. Only ever called from
/// `main()` behind `kDebugMode`, and only when the rides table is still
/// empty, so it never touches real ride data.
Future<void> seedSampleRidesIfEmpty(
  RideRepository rides,
  TrackpointRepository trackpoints,
) async {
  if ((await rides.getAllRides().first).isNotEmpty) return;

  final now = DateTime.now();
  final slotInPeriod = <_SeedPeriod, int>{};
  for (final route in _sampleRoutes) {
    final slot = slotInPeriod[route.period] ?? 0;
    slotInPeriod[route.period] = slot + 1;
    final slotCount =
        _sampleRoutes.where((r) => r.period == route.period).length;
    final startMs = _seedStart(route.period, slot, slotCount, now)
        .millisecondsSinceEpoch;
    final speedMs = route.speedKmh / 3.6;
    final points = _densify(route.waypoints, stepsPerLeg: 4);
    final rideId = await rides.startRide(
      activityTypeId: route.activity.id,
      startedAtMs: startMs,
    );
    var t = startMs;
    ({double lat, double lng})? prev;
    for (final p in points) {
      // Space timestamps by actual distance at the route's constant pace,
      // rather than a fixed interval — otherwise a long route's widely-spaced
      // waypoints compute an absurd average speed (a fixed 5s step over a
      // 6.5 km route worked out to ~220 km/h).
      if (prev != null) {
        final meters = _distanceMeters(prev, p);
        t += (meters / speedMs * 1000).round();
      }
      await trackpoints.addTrackpoint(
        rideId: rideId,
        latitude: p.lat,
        longitude: p.lng,
        timestampMs: t,
        speedMs: speedMs,
      );
      prev = p;
    }
    await rides.updateEndTime(rideId, t);
    await rides.updateRideDetails(rideId, route.title, null);
  }
}

/// Which of Home's stat windows a sample ride lands in. Each period's rides
/// fall strictly inside it and outside the narrower ones, so the hero card's
/// Heute / Diese Woche / Dieses Jahr numbers are cumulative but distinct:
/// today ⊂ this week ⊂ this year, and last year's rides show up in none of
/// them (only in History's year filter).
enum _SeedPeriod { today, thisWeek, thisYear, lastYear }

/// Start time of the [slot]-th of [slotCount] rides in [period], relative to
/// [now] (local time).
///
/// Degenerate calendar positions fall back to the next wider period rather
/// than into the future or a narrower one: on a Monday there are no earlier
/// days this week, so `thisWeek` rides land in last week (then "Diese Woche"
/// equals "Heute"); in the first days of January before the first Monday,
/// `thisYear` rides land in last year.
DateTime _seedStart(_SeedPeriod period, int slot, int slotCount, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final weekStart =
      DateTime(now.year, now.month, now.day - (now.weekday - DateTime.monday));
  final yearStart = DateTime(now.year);
  switch (period) {
    case _SeedPeriod.today:
      // Evenly spaced between midnight and now, so they're already over.
      return today.add(now.difference(today) * ((slot + 1) / (slotCount + 1)));
    case _SeedPeriod.thisWeek:
      final earlierDays = today.difference(weekStart).inDays;
      if (earlierDays == 0) {
        return DateTime(today.year, today.month, today.day - 1 - slot, 17);
      }
      return DateTime(weekStart.year, weekStart.month,
          weekStart.day + slot % earlierDays, 17 + slot);
    case _SeedPeriod.thisYear:
      final spanDays = weekStart.difference(yearStart).inDays;
      if (spanDays <= 0) {
        return DateTime(now.year - 1, 6, 1 + slot, 17);
      }
      return DateTime(now.year, 1, 1 + spanDays * slot ~/ slotCount, 17);
    case _SeedPeriod.lastYear:
      return DateTime(now.year - 1, 3 + slot * 3, 15, 17);
  }
}

class _SampleRoute {
  const _SampleRoute({
    required this.title,
    required this.activity,
    required this.period,
    required this.speedKmh,
    required this.waypoints,
  });

  final String title;
  final ActivityType activity;
  final _SeedPeriod period;

  /// Constant pace the route's trackpoints are generated at, varied per ride
  /// so each stat window's Ø km/h differs.
  final double speedKmh;
  final List<({double lat, double lng})> waypoints;
}

/// Every ride starts here (central Nuremberg — same ballpark as the existing
/// map-projection test fixtures) and heads out at its own bearing/distance.
const _cityCenter = (lat: 49.4521, lng: 11.0767);

const double _kmPerDegLat = 111.32;
final double _kmPerDegLon = 111.32 * math.cos(49.45 * math.pi / 180);

/// A point [km] out from [from] on compass bearing [bearingDeg] (0 = north,
/// clockwise). Flat-earth approximation — plenty accurate at city scale.
({double lat, double lng}) _offset(
    ({double lat, double lng}) from, double bearingDeg, double km) {
  final rad = bearingDeg * math.pi / 180;
  return (
    lat: from.lat + (km * math.cos(rad)) / _kmPerDegLat,
    lng: from.lng + (km * math.sin(rad)) / _kmPerDegLon,
  );
}

/// Straight-line distance between two points, in metres — same flat-earth
/// approximation as [_offset], just inverted.
double _distanceMeters(
    ({double lat, double lng}) a, ({double lat, double lng}) b) {
  final dLat = (b.lat - a.lat) * _kmPerDegLat * 1000;
  final dLng = (b.lng - a.lng) * _kmPerDegLon * 1000;
  return math.sqrt(dLat * dLat + dLng * dLng);
}

/// A gently meandering route of [totalKm] from [_cityCenter] heading roughly
/// [baseBearingDeg], as a handful of waypoints (later densified into a real
/// trackpoint sequence). Leg count scales with distance, so short rides stay
/// a couple of points and long ones get enough turns to look like a route.
List<({double lat, double lng})> _route({
  required double totalKm,
  required double baseBearingDeg,
}) {
  final legs = totalKm < 0.2 ? 1 : (totalKm / 1.5).ceil().clamp(3, 10);
  final legKm = totalKm / legs;
  final points = <({double lat, double lng})>[_cityCenter];
  var current = _cityCenter;
  var bearing = baseBearingDeg;
  for (var i = 0; i < legs; i++) {
    final jitter = (i.isEven ? 1 : -1) * 20.0;
    current = _offset(current, bearing + jitter, legKm);
    points.add(current);
    bearing += 8;
  }
  return points;
}

/// 15 routes, distances deliberately out of order (short/long alternating)
/// and cycling through every [ActivityType.values] entry. Periods: 2 today,
/// 3 earlier this week, 7 earlier this year, 3 last year.
final _sampleRoutes = <_SampleRoute>[
  _SampleRoute(
      title: 'Kurzer Test',
      activity: ActivityType.longboard,
      period: _SeedPeriod.thisYear,
      speedKmh: 6,
      waypoints: _route(totalKm: 0.05, baseBearingDeg: 0)),
  _SampleRoute(
      title: 'Fürth-Ausflug',
      activity: ActivityType.skateboard,
      period: _SeedPeriod.thisWeek,
      speedKmh: 16,
      waypoints: _route(totalKm: 8.0, baseBearingDeg: 24)),
  _SampleRoute(
      title: 'Vor der Haustür',
      activity: ActivityType.rollerblades,
      period: _SeedPeriod.thisYear,
      speedKmh: 9,
      waypoints: _route(totalKm: 0.4, baseBearingDeg: 48)),
  _SampleRoute(
      title: 'Kanaltour Nord',
      activity: ActivityType.rollerskates,
      period: _SeedPeriod.thisYear,
      speedKmh: 13,
      waypoints: _route(totalKm: 14.0, baseBearingDeg: 72)),
  _SampleRoute(
      title: 'Parkplatz-Runde',
      activity: ActivityType.mountainboard,
      period: _SeedPeriod.thisWeek,
      speedKmh: 8,
      waypoints: _route(totalKm: 0.9, baseBearingDeg: 96)),
  _SampleRoute(
      title: 'Pegnitzufer-Tour',
      activity: ActivityType.scooter,
      period: _SeedPeriod.thisYear,
      speedKmh: 11,
      waypoints: _route(totalKm: 5.0, baseBearingDeg: 120)),
  _SampleRoute(
      title: 'Feierabendrunde',
      activity: ActivityType.other,
      period: _SeedPeriod.thisYear,
      speedKmh: 10,
      waypoints: _route(totalKm: 1.3, baseBearingDeg: 144)),
  _SampleRoute(
      title: 'Groß-Rundfahrt',
      activity: ActivityType.longboard,
      period: _SeedPeriod.thisYear,
      speedKmh: 15,
      waypoints: _route(totalKm: 19.0, baseBearingDeg: 168)),
  _SampleRoute(
      title: 'Kleine Erkundung',
      activity: ActivityType.skateboard,
      period: _SeedPeriod.thisYear,
      speedKmh: 12,
      waypoints: _route(totalKm: 1.8, baseBearingDeg: 192)),
  _SampleRoute(
      title: 'Altstadt-Loop',
      activity: ActivityType.rollerblades,
      period: _SeedPeriod.today,
      speedKmh: 10,
      waypoints: _route(totalKm: 4.2, baseBearingDeg: 216)),
  _SampleRoute(
      title: 'Skatepark-Hop',
      activity: ActivityType.rollerskates,
      period: _SeedPeriod.thisWeek,
      speedKmh: 12,
      waypoints: _route(totalKm: 2.2, baseBearingDeg: 240)),
  _SampleRoute(
      title: 'Fluss entlang',
      activity: ActivityType.mountainboard,
      period: _SeedPeriod.lastYear,
      speedKmh: 14,
      waypoints: _route(totalKm: 10.0, baseBearingDeg: 264)),
  _SampleRoute(
      title: 'Nachbarschafts-Sprint',
      activity: ActivityType.scooter,
      period: _SeedPeriod.lastYear,
      speedKmh: 17,
      waypoints: _route(totalKm: 2.8, baseBearingDeg: 288)),
  _SampleRoute(
      title: 'Uferweg-Tour',
      activity: ActivityType.other,
      period: _SeedPeriod.lastYear,
      speedKmh: 12,
      waypoints: _route(totalKm: 6.5, baseBearingDeg: 312)),
  _SampleRoute(
      title: 'Feierabend-Express',
      activity: ActivityType.longboard,
      period: _SeedPeriod.today,
      speedKmh: 14,
      waypoints: _route(totalKm: 3.5, baseBearingDeg: 336)),
];

/// Linearly interpolates [stepsPerLeg] extra points between each pair of
/// waypoints, so a route reads as a real trackpoint sequence rather than a
/// handful of sparse corners.
List<({double lat, double lng})> _densify(
  List<({double lat, double lng})> waypoints, {
  required int stepsPerLeg,
}) {
  final out = <({double lat, double lng})>[];
  for (var i = 0; i < waypoints.length - 1; i++) {
    final a = waypoints[i], b = waypoints[i + 1];
    for (var s = 0; s < stepsPerLeg; s++) {
      final f = s / stepsPerLeg;
      out.add((
        lat: a.lat + (b.lat - a.lat) * f,
        lng: a.lng + (b.lng - a.lng) * f,
      ));
    }
  }
  out.add(waypoints.last);
  return out;
}
