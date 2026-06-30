import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

Widget _stubMap(BuildContext _) => const SizedBox(key: ValueKey('stub-map'));

/// Installs the static [LiveMap.debugMapBuilderOverride] for every test in the
/// enclosing `main()`/`group`, so a pumped `LiveMap` renders an inert stub
/// instead of the native `MapLibreMap` (which throws `UnimplementedError` under
/// `flutter test`). Cleared in `tearDown` so it never leaks across tests.
void useStubLiveMap() {
  setUp(() => LiveMap.debugMapBuilderOverride = _stubMap);
  tearDown(() => LiveMap.debugMapBuilderOverride = null);
}
