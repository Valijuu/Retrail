import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;

/// Returns whether the device currently advertises *any* network with internet.
typedef HasNetwork = Future<bool> Function();

/// Reports whether the device has **real** internet access, as a `Stream<bool>`.
///
/// Deliberately does NOT trust the OS "validated" capability flag, because it is
/// unreliable behind a VPN (e.g. NordVPN keeps reporting validated internet with
/// no underlying connectivity). The only dependable signal is an actual request,
/// so this runs a short HTTP probe to a `generate_204` endpoint that traverses
/// the VPN tunnel. Ported from the original `ConnectivityObserver`.
///
/// Re-evaluates on each connectivity-change event and on a periodic poll, only
/// while observed. Seams (http client, network check, change stream) are
/// injectable for tests.
class ConnectivityObserver {
  ConnectivityObserver({
    http.Client? httpClient,
    HasNetwork? hasNetwork,
    Stream<void>? onChange,
    this.pollInterval = const Duration(seconds: 10),
    this.probeUrl = 'https://clients3.google.com/generate_204',
    this.probeTimeout = const Duration(milliseconds: 2500),
  })  : _client = httpClient ?? http.Client(),
        _hasNetwork = hasNetwork ?? _defaultHasNetwork,
        _onChange = onChange ?? _defaultOnChange();

  final http.Client _client;
  final HasNetwork _hasNetwork;
  final Stream<void> _onChange;
  final Duration pollInterval;
  final String probeUrl;
  final Duration probeTimeout;

  /// One reachability evaluation: fast-path offline when there's no network,
  /// else an HTTP probe (status 200–399 ⇒ online). Never throws.
  Future<bool> checkNow() async {
    if (!await _hasNetwork()) return false;
    try {
      final response =
          await _client.get(Uri.parse(probeUrl)).timeout(probeTimeout);
      return response.statusCode >= 200 && response.statusCode < 400;
    } catch (_) {
      return false;
    }
  }

  /// Distinct online/offline stream: seeds on listen, re-evaluates on change
  /// events and every [pollInterval], and only emits when the value changes.
  Stream<bool> get isOnline {
    late StreamController<bool> controller;
    StreamSubscription<void>? changeSub;
    Timer? timer;
    bool? last;
    var evaluating = false;

    Future<void> evaluate() async {
      if (evaluating) return; // rough mapLatest: ignore overlapping probes
      evaluating = true;
      try {
        final online = await checkNow();
        if (online != last) {
          last = online;
          controller.add(online);
        }
      } finally {
        evaluating = false;
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        evaluate();
        changeSub = _onChange.listen((_) => evaluate());
        timer = Timer.periodic(pollInterval, (_) => evaluate());
      },
      onCancel: () async {
        await changeSub?.cancel();
        timer?.cancel();
      },
    );
    return controller.stream;
  }

  static Future<bool> _defaultHasNetwork() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty && !results.contains(ConnectivityResult.none);
  }

  static Stream<void> _defaultOnChange() =>
      Connectivity().onConnectivityChanged.map((_) {});
}
