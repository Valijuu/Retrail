// Builds a demo database for store screenshots: rides on Tempelhofer Feld,
// Berlin (a public park, no one's home), written through the real
// repositories so stored stats match what the app computes.
//
//   flutter test tool/demo_rides/build_demo_db_test.dart
//   RETRAIL_DEMO_LANG=de flutter test tool/demo_rides/build_demo_db_test.dart
//
// Writes build/demo_rides/retrail_<lang>.sqlite with ride titles in that
// language (en by default). Ride dates are relative to now, so
// the home screen's week/day totals are filled. Route geometry in
// routes.json is from OpenStreetMap (© OpenStreetMap contributors, ODbL).
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/db/app_database.dart';
import 'package:retrail/data/repositories/ride_repository.dart';
import 'package:retrail/data/repositories/trackpoint_repository.dart';
import 'package:retrail/domain/activity_type.dart';

typedef LatLng = List<double>;

class DemoRide {
  const DemoRide({
    required this.daysAgo,
    required this.hour,
    required this.minute,
    required this.type,
    required this.route,
    required this.cruiseKmh,
    this.title,
    this.comment,
    this.favorite = false,
  });

  final int daysAgo;
  final int hour;
  final int minute;
  final ActivityType type;
  final List<LatLng> route;
  final double cruiseKmh;
  final String? title;
  final String? comment;
  final bool favorite;
}

void main() {
  test('build the demo database', () async {
    final routes =
        (jsonDecode(File('tool/demo_rides/routes.json').readAsStringSync())
                as Map<String, dynamic>)
            .map(
              (k, v) => MapEntry(k, [
                for (final p in v as List)
                  [(p as List)[0] as double, p[1] as double],
              ]),
            );
    List<LatLng> r(String name) => routes[name]!;
    List<LatLng> back(List<LatLng> l) => l.reversed.toList();
    List<LatLng> outAndBack(List<LatLng> l) => [...l, ...back(l).skip(1)];
    // South runway eastwards, across to the north runway, back west, and
    // across to the start again.
    final loop = [
      ...r('south_runway'),
      ...back(r('north_runway')),
      r('south_runway').first,
    ];

    final lang = Platform.environment['RETRAIL_DEMO_LANG'] ?? 'en';
    final de = lang == 'de';
    final rides = [
      DemoRide(
        daysAgo: 0,
        hour: 8,
        minute: 40,
        title: de ? 'Runde übers Feld' : 'Runway loop',
        comment: de
            ? 'Glatter Asphalt und leichter Rückenwind auf der Südbahn.'
            : 'Smooth asphalt and a light tailwind on the south runway.',
        type: ActivityType.longboard,
        route: loop,
        cruiseKmh: 19,
        favorite: true,
      ),
      DemoRide(
        daysAgo: 1,
        hour: 18,
        minute: 5,
        title: de ? 'Feierabendrunde' : 'Evening skate',
        comment: de
            ? 'Nach der Arbeit die Nordbahn hoch und runter.'
            : 'Up and down the north runway after work.',
        type: ActivityType.rollerblades,
        route: outAndBack(r('north_runway')),
        cruiseKmh: 17,
      ),
      DemoRide(
        daysAgo: 3,
        hour: 17,
        minute: 30,
        title: de ? 'Kurze Session' : 'Quick session',
        comment: de
            ? 'Pushen üben auf den Pflastersteinen.'
            : 'Practising pushes on the paving stones.',
        type: ActivityType.skateboard,
        route: r('middle_path'),
        cruiseKmh: 12,
      ),
      DemoRide(
        daysAgo: 5,
        hour: 10,
        minute: 15,
        title: de ? 'Rollbahn-Cruise' : 'Runway cruise',
        comment: de
            ? 'Neue Rollen, merklich schneller.'
            : 'New wheels, noticeably faster.',
        type: ActivityType.longboard,
        route: outAndBack(r('south_runway')),
        cruiseKmh: 21,
      ),
      DemoRide(
        daysAgo: 8,
        hour: 19,
        minute: 0,
        title: de ? 'Über die Wiese' : 'Across the grass',
        comment: de
            ? 'Holprig, aber spaßig auf dem Wiesenweg.'
            : 'Bumpy but fun on the grass path.',
        type: ActivityType.mountainboard,
        route: r('grass_path'),
        cruiseKmh: 14,
      ),
      DemoRide(
        daysAgo: 12,
        hour: 16,
        minute: 45,
        title: de ? 'Rollerrunde' : 'Scooter laps',
        comment: de
            ? 'Entspannt den Südweg entlang.'
            : 'Easy ride along the southern path.',
        type: ActivityType.scooter,
        route: outAndBack(r('south_footway')),
        cruiseKmh: 13,
      ),
      DemoRide(
        daysAgo: 16,
        hour: 11,
        minute: 20,
        title: de ? 'Sonntagsrunde' : 'Sunday roll',
        comment: de ? 'Ganze Runde mit Freunden.' : 'Full loop with friends.',
        type: ActivityType.rollerskates,
        route: loop,
        cruiseKmh: 15,
      ),
      DemoRide(
        daysAgo: 21,
        hour: 18,
        minute: 30,
        title: de ? 'Abendsonne' : 'Sunset ride',
        comment: de
            ? 'Goldene Stunde auf dem Feld.'
            : 'Golden hour on the field.',
        type: ActivityType.longboard,
        route: [...r('dirt_path'), ...back(r('south_runway'))],
        cruiseKmh: 18,
        favorite: true,
      ),
      DemoRide(
        daysAgo: 29,
        hour: 9,
        minute: 50,
        title: de ? 'Morgenrunden' : 'Morning laps',
        comment: de
            ? 'Früh unterwegs, bevor es voll wurde.'
            : 'Early laps before it got busy.',
        type: ActivityType.rollerblades,
        route: loop,
        cruiseKmh: 18,
      ),
      DemoRide(
        daysAgo: 40,
        hour: 17,
        minute: 10,
        title: de ? 'Kurze Skaterunde' : 'Short skate',
        comment: de ? 'Viele Pausen für Tricks.' : 'Lots of stops for tricks.',
        type: ActivityType.skateboard,
        route: outAndBack(r('middle_path')),
        cruiseKmh: 11,
      ),
    ];

    final file = File('build/demo_rides/retrail_$lang.sqlite');
    file.parent.createSync(recursive: true);
    if (file.existsSync()) file.deleteSync();
    final db = AppDatabase(NativeDatabase(file));
    final rideRepo = RideRepository(db.rideDao);
    final trackRepo = TrackpointRepository(db.trackpointDao);
    final random = math.Random(7);
    final today = DateTime.now();

    for (final ride in rides) {
      final day = today.subtract(Duration(days: ride.daysAgo));
      final start = DateTime(
        day.year,
        day.month,
        day.day,
        ride.hour,
        ride.minute,
      ).millisecondsSinceEpoch;
      final id = await rideRepo.startRide(
        activityTypeId: ride.type.id,
        startedAtMs: start,
      );
      final fixes = _simulate(ride.route, ride.cruiseKmh, random);
      await db.transaction(() async {
        for (var i = 0; i < fixes.length; i++) {
          await trackRepo.addTrackpoint(
            rideId: id,
            latitude: fixes[i].lat,
            longitude: fixes[i].lng,
            timestampMs: start + i * 1000,
            speedMs: fixes[i].speedMs,
          );
        }
      });
      await rideRepo.updateEndTime(id, start + fixes.length * 1000);
      if (ride.title != null || ride.comment != null) {
        await rideRepo.updateRideDetails(id, ride.title, ride.comment);
      }
      if (ride.favorite) await rideRepo.updateFavorite(id, true);
    }
    await db.close();
  }, timeout: Timeout.none);
}

class _Fix {
  const _Fix(this.lat, this.lng, this.speedMs);
  final double lat;
  final double lng;
  final double speedMs;
}

const double _mPerDegLat = 111320;

/// One fix per second along [route] at a speed that swells and dips around
/// [cruiseKmh] (pushes, gentle slopes, slowing for turns), with ~1 m of GPS
/// scatter across the line.
List<_Fix> _simulate(List<LatLng> route, double cruiseKmh, math.Random random) {
  final mPerDegLng = _mPerDegLat * math.cos(route.first[0] * math.pi / 180);
  final cumulative = <double>[0];
  for (var i = 1; i < route.length; i++) {
    final dy = (route[i][0] - route[i - 1][0]) * _mPerDegLat;
    final dx = (route[i][1] - route[i - 1][1]) * mPerDegLng;
    cumulative.add(cumulative.last + math.sqrt(dx * dx + dy * dy));
  }
  final total = cumulative.last;
  final fixes = <_Fix>[];
  var along = 0.0;
  var t = 0;
  var seg = 0;
  while (along < total) {
    while (seg < route.length - 2 && cumulative[seg + 1] < along) {
      seg++;
    }
    final segLen = cumulative[seg + 1] - cumulative[seg];
    final f = segLen == 0 ? 0.0 : (along - cumulative[seg]) / segLen;
    final a = route[seg];
    final b = route[seg + 1];
    final jitter = (random.nextDouble() - 0.5) * 2.0;
    final lat = a[0] + (b[0] - a[0]) * f + jitter / _mPerDegLat;
    final lng = a[1] + (b[1] - a[1]) * f + jitter / mPerDegLng;
    final kmh = math.max(
      4.0,
      cruiseKmh * (1 + 0.18 * math.sin(t / 23) + 0.08 * math.sin(t / 7)) +
          (random.nextDouble() - 0.5) * 2.5,
    );
    final ms = kmh / 3.6;
    fixes.add(_Fix(lat, lng, ms));
    along += ms;
    t++;
  }
  return fixes;
}
