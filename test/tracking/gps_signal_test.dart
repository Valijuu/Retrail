import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/tracking/gps_fix_filter.dart';
import 'package:retrail/tracking/gps_signal.dart';
import 'package:retrail/tracking/location_fix.dart';

const _nanosPerSecond = 1000000000;
const _now = 100 * _nanosPerSecond;

/// Comfortably inside [GpsFixFilter.accuracyThresholdM].
const _goodAccuracyM = 5.0;

/// The smallest step past a threshold the tests probe.
const _accuracyOverstepM = 0.1;
const _ageOverstepNanos = 1;

const _anyLatitude = 50.0;
const _anyLongitude = 8.0;

LocationFix _fix({double accuracy = _goodAccuracyM, int ageNanos = 0}) =>
    LocationFix(
      latitude: _anyLatitude,
      longitude: _anyLongitude,
      accuracy: accuracy,
      hasSpeed: false,
      speed: 0,
      elapsedRealtimeNanos: _now - ageNanos,
    );

GpsSignal _signal(LocationFix? fix, {bool serviceEnabled = true}) =>
    gpsSignal(fix: fix, serviceEnabled: serviceEnabled, nowNanos: _now);

void main() {
  group('gpsSignal (#69)', () {
    test('no fix yet → searching', () {
      expect(_signal(null), GpsSignal.searching);
    });
    test('a fresh fix within 35 m → ready', () {
      expect(_signal(_fix()), GpsSignal.ready);
    });
    test('accuracy just over 35 m → searching', () {
      expect(
        _signal(
          _fix(accuracy: GpsFixFilter.accuracyThresholdM + _accuracyOverstepM),
        ),
        GpsSignal.searching,
      );
    });
    test('accuracy exactly 35 m → ready', () {
      expect(
        _signal(_fix(accuracy: GpsFixFilter.accuracyThresholdM)),
        GpsSignal.ready,
      );
    });
    test('a fix older than 5 s (stale seed / last ride) → searching', () {
      expect(
        _signal(
          _fix(ageNanos: GpsFixFilter.maxFixAgeNanos + _ageOverstepNanos),
        ),
        GpsSignal.searching,
      );
    });
    test('a fix exactly 5 s old → still ready', () {
      expect(
        _signal(_fix(ageNanos: GpsFixFilter.maxFixAgeNanos)),
        GpsSignal.ready,
      );
    });
    test('location services off → off, even with a fresh accurate fix', () {
      expect(_signal(_fix(), serviceEnabled: false), GpsSignal.off);
    });
    test('location services off and no fix → off', () {
      expect(_signal(null, serviceEnabled: false), GpsSignal.off);
    });
  });
}
