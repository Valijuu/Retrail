import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../data/repositories/data_providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../map/preview_projection.dart';
import '../../../map/route_preview.dart';
import '../../active_ride/active_ride_providers.dart';

/// [rideId]'s route as plain points, fetched only when actually needed (a
/// not-yet-cached preview render, or a navigate-to-start tap) — the history
/// list itself no longer joins trackpoints (issue #21).
Future<List<RoutePoint>> loadRidePoints(WidgetRef ref, int rideId) async {
  final tps = await ref
      .read(trackpointRepositoryProvider)
      .getForRide(rideId)
      .first;
  return [for (final tp in tps) (lat: tp.latitude, lng: tp.longitude)];
}

/// A ride's cached route preview on the map-terrain backdrop, or "No route"
/// for a ride without one. Fills its parent; callers size and clip it.
class RidePreviewThumbnail extends ConsumerWidget {
  const RidePreviewThumbnail({
    super.key,
    required this.rideId,
    required this.hasRoute,
  });

  final int rideId;
  final bool hasRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    return ColoredBox(
      color: hasRoute ? colors.mapTerrain : colors.mapTerrainGrid,
      child: hasRoute
          ? RoutePreview(
              rideId: rideId,
              hasRoute: true,
              pointsLoader: () => loadRidePoints(ref, rideId),
              cache: ref.watch(routePreviewCacheProvider),
              cacheWidth: previewImageCacheWidth,
            )
          : Center(
              child: Text(
                AppLocalizations.of(context).chipNoRoute,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}
