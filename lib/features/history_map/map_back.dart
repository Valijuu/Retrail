import 'package:flutter_riverpod/flutter_riverpod.dart';

/// What the Back button closes on the map before it leaves the tab (#115):
/// the open activity menu, the place search, then the ride card. Returns
/// whether it closed something. The mounted map view registers it, the
/// History screen asks it.
class MapBackNotifier extends Notifier<bool Function()?> {
  @override
  bool Function()? build() => null;

  void register(bool Function()? handler) => state = handler;
}

final mapBackProvider = NotifierProvider<MapBackNotifier, bool Function()?>(
  MapBackNotifier.new,
);
