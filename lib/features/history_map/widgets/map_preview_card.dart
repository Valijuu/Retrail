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
/// header for the best-time badge, the route's ride count, the `n/m` pager
/// and a close control. Swipe sideways to move through different routes
/// under the tap; the rides of one route open from the count (#96).
class MapPreviewCard extends StatelessWidget {
  const MapPreviewCard({
    super.key,
    required this.rides,
    required this.index,
    required this.actions,
    required this.onSelect,
    required this.onClose,
  });

  final List<SelectedRide> rides;
  final int index;
  final MapCardActions actions;

  /// Called with the id of the ride to show next.
  final ValueChanged<int> onSelect;
  final VoidCallback onClose;

  /// A sideways fling faster than this moves to the next or previous ride.
  static const double _swipeVelocity = 200;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final at = index.clamp(0, rides.length - 1);
    final ride = rides[at];
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -_swipeVelocity && at < rides.length - 1) {
          onSelect(rides[at + 1].entry.ride.rideId);
        }
        if (v > _swipeVelocity && at > 0) {
          onSelect(rides[at - 1].entry.ride.rideId);
        }
      },
      child: Material(
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
                  // The route's ride count opens the whole route group, so the
                  // card shows one entry per route (#96). It takes the room
                  // left of the pager and wraps instead of being cut (#103).
                  if (ride.groupSize > 1)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: () => actions.onOpenRouteGroup(ride),
                          iconAlignment: IconAlignment.end,
                          icon: const Icon(Icons.chevron_right, size: 18),
                          label: Text(
                            l10n.historyMapRidesOnRoute(ride.groupSize),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (rides.length > 1) ...[
                    IconButton(
                      onPressed: at > 0
                          ? () => onSelect(rides[at - 1].entry.ride.rideId)
                          : null,
                      tooltip: l10n.historyMapPreviousRoute,
                      icon: const Icon(Icons.chevron_left),
                    ),
                    Text(
                      l10n.historyMapCardCounter(at + 1, rides.length),
                      style: text.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    IconButton(
                      onPressed: at < rides.length - 1
                          ? () => onSelect(rides[at + 1].entry.ride.rideId)
                          : null,
                      tooltip: l10n.historyMapNextRoute,
                      icon: const Icon(Icons.chevron_right),
                    ),
                  ],
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
      ),
    );
  }
}
