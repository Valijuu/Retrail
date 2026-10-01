import 'dart:convert';
import 'dart:io';

import 'package:retrail/domain/follow_direction.dart';

import 'sim_metrics.dart';
import 'sim_route.dart';

/// The user's real rides, local only: private location data, gitignored and
/// never committed. `{"rides": {"<id>": [[northM, eastM, tSeconds], ...]}}`.
const realRidesPath = 'test/fixtures/real_rides.json';

/// The real rides by id as local metres, or null when the fixture is absent.
Map<String, List<Xy>>? loadRealRides() {
  final file = File(realRidesPath);
  if (!file.existsSync()) return null;
  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final rides = json['rides'] as Map<String, dynamic>;
  return {
    for (final MapEntry(:key, :value) in rides.entries)
      key: [
        for (final p in value as List<dynamic>)
          (
            n: ((p as List<dynamic>)[0] as num).toDouble(),
            e: (p[1] as num).toDouble(),
          ),
      ],
  };
}

/// A real ride's fixes followed along a route (its own, or another ride's).
/// [trueS]: where the rider really is, in route metres (unwrapped); for a
/// ride along its own route these are its own vertices. Null: projected.
class RealCase {
  RealCase(this.check, this.fixes, {this.trueS});

  final FollowCase check;
  final List<Xy> fixes;
  final List<double>? trueS;
}

/// The failed metrics of [rc]. Without known [RealCase.trueS], where the
/// rider really is comes from projecting each fix onto the route, next to
/// the previous one.
Set<Metric> runReal(RealCase rc, {void Function(String)? log}) {
  var trueS = rc.trueS;
  if (trueS == null) {
    trueS = <double>[];
    for (final f in rc.fixes) {
      final nearS = trueS.isEmpty ? null : trueS.last;
      trueS.add(rc.check.route.project(f, nearS: nearS).s);
    }
  }
  return evaluate(rc.check, trueS, rc.fixes, null, log: log);
}

List<T> _from<T>(List<T> xs, double share) =>
    xs.sublist((xs.length * share).round());

/// The replay cases: every ride along itself from the start, reversed from
/// the finish, and joined at 40 % of its fixes either way; ride 8 ↔ ride 10
/// (10 ridden in reverse); ride 4 along ride 3 (a stretch of 3 in reverse);
/// ride 6 (a ~12 km loop) across its seam both ways.
List<RealCase> realCases(Map<String, List<Xy>> rides) {
  const fwd = FollowDirection.forward, rev = FollowDirection.reverse;
  final routes = {
    for (final MapEntry(:key, :value) in rides.entries)
      key: SimRoute('ride $key', value),
  };
  RealCase along(
    String routeId,
    String what,
    List<Xy> fixes,
    FollowDirection expected, {
    required bool endsAtFinish,
    List<double>? trueS,
  }) => RealCase(
    FollowCase(
      'ride $routeId · $what',
      route: routes[routeId]!,
      expected: expected,
      endsAtFinish: endsAtFinish,
    ),
    fixes,
    trueS: trueS,
  );

  final cases = <RealCase>[];
  for (final MapEntry(key: id, value: fixes) in rides.entries) {
    final route = routes[id]!;
    final s = route.cumulativeM;
    final back = fixes.reversed.toList(), backS = s.reversed.toList();
    cases.addAll([
      along(
        id,
        'itself from the start',
        fixes,
        fwd,
        endsAtFinish: true,
        trueS: s,
      ),
      along(
        id,
        'reversed from the finish',
        back,
        rev,
        endsAtFinish: true,
        trueS: backS,
      ),
      along(
        id,
        'itself from 40 %',
        _from(fixes, 0.4),
        fwd,
        endsAtFinish: !route.isLoop,
        trueS: _from(s, 0.4),
      ),
      along(
        id,
        'reversed from 60 %',
        _from(back, 0.4),
        rev,
        endsAtFinish: !route.isLoop,
        trueS: _from(backS, 0.4),
      ),
    ]);
  }
  if (rides.containsKey('8') && rides.containsKey('10')) {
    cases.addAll([
      along('10', 'ride 8 fixes', rides['8']!, rev, endsAtFinish: true),
      along('8', 'ride 10 fixes', rides['10']!, rev, endsAtFinish: true),
    ]);
  }
  if (rides.containsKey('3') && rides.containsKey('4')) {
    cases.add(
      along('3', 'ride 4 fixes', rides['4']!, rev, endsAtFinish: false),
    );
  }
  final loop = rides['6'];
  if (loop != null) {
    final n = loop.length, s = routes['6']!.cumulativeM;
    final lapM = routes['6']!.lengthM;
    final from = (n * 0.8).round(), to = (n * 0.2).round();
    final seam = [...loop.sublist(from), ...loop.sublist(1, to)];
    final seamS = [
      ...s.sublist(from),
      for (final m in s.sublist(1, to)) lapM + m,
    ];
    cases.addAll([
      along(
        '6',
        'across the seam',
        seam,
        fwd,
        endsAtFinish: false,
        trueS: seamS,
      ),
      along(
        '6',
        'across the seam reversed',
        seam.reversed.toList(),
        rev,
        endsAtFinish: false,
        trueS: seamS.reversed.toList(),
      ),
    ]);
  }
  return cases;
}
