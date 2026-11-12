import 'package:flutter/material.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../core/theme/theme_context.dart';
import '../../../l10n/app_localizations.dart';
import '../../history/history_ride_card.dart';
import '../map_selection.dart';

/// What the preview card does with its ride; the History screen supplies
/// these, so the card behaves exactly as in the list.
class MapCardActions {
  const MapCardActions({
    required this.onOpenDetail,
    required this.onEdit,
    required this.onDelete,
    required this.onFollowRoute,
    required this.onOpenRouteGroup,
    required this.onToggleFavorite,
  });

  final void Function(SelectedRide ride) onOpenDetail;
  final void Function(SelectedRide ride) onEdit;
  final void Function(SelectedRide ride) onDelete;
  final void Function(SelectedRide ride) onFollowRoute;
  final void Function(SelectedRide ride) onOpenRouteGroup;
  final void Function(SelectedRide ride) onToggleFavorite;
}

/// The tapped ride at the bottom of the map: the History card itself, with a
/// header for the best-time badge, the route's ride count and a close
/// control. One card per tap: the nearest route's best ride; the route's other
/// rides open from the count (#96, #109).
class MapPreviewCard extends StatelessWidget {
  const MapPreviewCard({
    super.key,
    required this.ride,
    required this.actions,
    required this.onClose,
  });

  final SelectedRide ride;
  final MapCardActions actions;

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    return Material(
      color: colors.surface,
      elevation: 4,
      borderRadius: AppShapes.heroCard,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (ride.isBest) ...[
                  Icon(Icons.emoji_events, size: 18, color: colors.primary),
                  const SizedBox(width: 4),
                  Text(
                    l10n.historyMapBestTime,
                    style: text.labelMedium?.copyWith(color: colors.primary),
                  ),
                  const SizedBox(width: 8),
                ],
                // The route's ride count opens the whole route group; the
                // card shows one ride and never pages (#96, #109). The short
                // label stays on one line (#103).
                if (ride.groupSize > 1)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      // The short label says how many; the tooltip and the
                      // screen reader say whose rides they are.
                      child: Tooltip(
                        message: l10n.historyMapRidesOnRoute(ride.groupSize),
                        child: TextButton.icon(
                          onPressed: () => actions.onOpenRouteGroup(ride),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: Text(
                            l10n.historyMapRideCount(ride.groupSize),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  onPressed: onClose,
                  tooltip: l10n.historyMapCloseCard,
                  icon: Icon(Icons.close, color: colors.onSurface),
                ),
              ],
            ),
            HistoryRideCard(
              key: ValueKey('map_card_${ride.entry.ride.rideId}'),
              entry: ride.entry,
              selectionMode: false,
              selected: false,
              highlighted: false,
              onTap: () => actions.onOpenDetail(ride),
              onOpenMap: () => actions.onOpenDetail(ride),
              onLongPress: () {},
              onEdit: () => actions.onEdit(ride),
              onDelete: () => actions.onDelete(ride),
              onFollowRoute: () => actions.onFollowRoute(ride),
              onOpenRouteGroup: () => actions.onOpenRouteGroup(ride),
              onToggleFavorite: () => actions.onToggleFavorite(ride),
            ),
          ],
        ),
      ),
    );
  }
}
