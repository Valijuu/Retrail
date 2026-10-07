import '../domain/distance_calculator.dart';
import 'gps_fix_filter.dart';
import 'location_fix.dart';
import 'ride_tracking_state.dart';

/// Builds a ride's recorded route from incoming fixes.
///
/// Runs each fix through [GpsFixFilter] and keeps what the filter needs
/// between fixes — the last recorded fix and the fixes held after a long stop
/// (#70) — plus the route so far. Pure Dart; [RideTracker] owns the ride
/// lifecycle and persists what this returns.
class RouteRecorder {
  RouteRecorder(this._calc);

  final DistanceCalculator _calc;

  LocationFix? _last;
  List<LocationFix> _pending = const [];
  List<RoutePoint> _points = const [];
  double _distanceMetres = 0.0;

  /// The recorded route, oldest first.
  List<RoutePoint> get points => _points;

  /// Total recorded distance.
  double get distanceMetres => _distanceMetres;

  /// Feeds [fix] through the filter and returns the fixes it records, in
  /// order: usually none or [fix]; after a long stop also the held fixes.
  List<LocationFix> add(LocationFix fix) {
    final decision = GpsFixFilter.evaluate(
      fix: fix,
      last: _last,
      pending: _pending,
      calc: _calc,
    );
    _pending = decision.pending;
    if (decision.recorded.isEmpty) return const [];

    final recorded = [for (final r in decision.recorded) r.fix];
    for (final r in decision.recorded) {
      _distanceMetres += r.distanceMetres;
    }
    _last = recorded.last;
    _points = [
      ..._points,
      for (final f in recorded) (lat: f.latitude, lng: f.longitude),
    ];
    return recorded;
  }

  /// Breaks the route after a pause: the next fix starts a fresh segment, so
  /// the gap isn't counted as one big distance jump.
  void breakSegment() {
    _last = null;
    _pending = const [];
  }

  /// Starts a new, empty route.
  void clear() {
    breakSegment();
    _points = const [];
    _distanceMetres = 0.0;
  }
}
