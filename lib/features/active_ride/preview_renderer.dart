import 'dart:typed_data';

import '../../map/preview_projection.dart';
import '../../map/route_preview_cache.dart';

/// Builds the [PreviewRenderer] used by the preview cache, choosing the renderer
/// **at call time**: online → full-tile snapshot, offline → flat sketch. Kept as
/// a small factory so the online/offline selection is unit-testable without
/// touching the network. See Spec 12 wiring.
PreviewRenderer buildPreviewRenderer({
  required bool Function() isOnline,
  required Future<Uint8List> Function(List<RoutePoint> points) online,
  required Future<Uint8List> Function(List<RoutePoint> points) offline,
}) =>
    (points) => isOnline() ? online(points) : offline(points);
