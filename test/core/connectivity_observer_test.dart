import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:retrail/core/connectivity/connectivity_observer.dart';

void main() {
  ConnectivityObserver build({
    required Future<http.Response> Function(http.Request) handler,
    bool hasNetwork = true,
    Stream<void>? onChange,
  }) =>
      ConnectivityObserver(
        httpClient: MockClient((req) => handler(req)),
        hasNetwork: () async => hasNetwork,
        onChange: onChange ?? const Stream.empty(),
        pollInterval: const Duration(hours: 1), // keep the poll out of the way
      );

  group('checkNow', () {
    test('no network → offline without probing', () async {
      var probed = false;
      final obs = build(
        hasNetwork: false,
        handler: (_) async {
          probed = true;
          return http.Response('', 204);
        },
      );
      expect(await obs.checkNow(), isFalse);
      expect(probed, isFalse);
    });

    test('probe 204 → online', () async {
      final obs = build(handler: (_) async => http.Response('', 204));
      expect(await obs.checkNow(), isTrue);
    });

    test('probe 500 → offline', () async {
      final obs = build(handler: (_) async => http.Response('', 500));
      expect(await obs.checkNow(), isFalse);
    });

    test('probe throwing → offline (does not propagate)', () async {
      final obs = build(handler: (_) async => throw Exception('no route'));
      expect(await obs.checkNow(), isFalse);
    });
  });

  group('isOnline stream', () {
    test('seeds the current value on listen', () async {
      final obs = build(handler: (_) async => http.Response('', 204));
      final emissions = <bool>[];
      final sub = obs.isOnline.listen(emissions.add);
      await pumpEventQueue();
      expect(emissions, [true]);
      await sub.cancel();
    });

    test('re-emits on a connectivity change, distinct only', () async {
      final changes = StreamController<void>.broadcast();
      var status = 204;
      final obs = build(
        handler: (_) async => http.Response('', status),
        onChange: changes.stream,
      );
      final emissions = <bool>[];
      final sub = obs.isOnline.listen(emissions.add);
      await pumpEventQueue();
      expect(emissions, [true]);

      // Goes offline → new emission.
      status = 500;
      changes.add(null);
      await pumpEventQueue();
      expect(emissions, [true, false]);

      // Still offline → no duplicate emission.
      changes.add(null);
      await pumpEventQueue();
      expect(emissions, [true, false]);

      await sub.cancel();
      await changes.close();
    });
  });
}
