import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../domain/formatters.dart';
import '../../../domain/ride_title.dart';
import '../../../domain/route_group.dart';
import '../../../l10n/app_localizations.dart';
import '../history_items.dart';
import '../route_group_providers.dart';

/// Opens the comparison of the route group of the original [rootId] (Spec 20).
/// A tapped row closes the sheet and hands its ride to [onOpenRide].
Future<void> showRouteGroupSheet(
  BuildContext context, {
  required int rootId,
  int? highlightRideId,
  required ValueChanged<RideEntryItem> onOpenRide,
}) => showAppScrollableSheet<void>(
  context: context,
  builder: (sheetContext, scrollController) => RouteGroupSheet(
    rootId: rootId,
    highlightRideId: highlightRideId,
    scrollController: scrollController,
    onOpenRide: (entry) {
      Navigator.of(sheetContext).pop();
      onOpenRide(entry);
    },
  ),
);

/// An original and the rides that followed it: the complete ones (the best
/// time marked) and the partial ones, which never compete for it (Spec 20).
class RouteGroupSheet extends ConsumerWidget {
  const RouteGroupSheet({
    super.key,
    required this.rootId,
    required this.onOpenRide,
    this.highlightRideId,
    this.scrollController,
  });

  final int rootId;

  /// The ride the sheet was opened from, shown selected.
  final int? highlightRideId;
  final ValueChanged<RideEntryItem> onOpenRide;

  /// The enclosing sheet's controller, so a drag on the list closes it.
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(routeGroupProvider(rootId)).value;
    if (view == null) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final group = view.group;
    final original = view.entries[rootId]!;

    Widget section(String label) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label.toUpperCase(),
        style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
      ),
    );
    Widget row(RouteGroupRide r) => _RideRow(
      entry: view.entries[r.rideId]!,
      best: r.rideId == group.bestRideId,
      selected: r.rideId == highlightRideId,
      onTap: onOpenRide,
    );

    return SafeArea(
      child: ListView(
        controller: scrollController,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    rideDisplayTitle(original.ride, locale: locale),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleLarge?.copyWith(color: colors.onSurface),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  formatShortDistanceKm(
                    original.stats.distanceMetres,
                    locale: locale,
                  ),
                  style: text.titleMedium?.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
          section(l10n.routeGroupOriginal),
          row(group.original),
          if (group.complete.isNotEmpty) ...[
            section(l10n.routeGroupFollows(group.complete.length)),
            for (final r in group.complete) row(r),
          ],
          if (group.partial.isNotEmpty) ...[
            section(l10n.routeGroupPartial),
            for (final r in group.partial) row(r),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

/// One ride of the group: date, then distance · duration · average speed.
class _RideRow extends StatelessWidget {
  const _RideRow({
    required this.entry,
    required this.best,
    required this.selected,
    required this.onTap,
  });

  final RideEntryItem entry;
  final bool best;
  final bool selected;
  final ValueChanged<RideEntryItem> onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final stats = entry.stats;
    return ListTile(
      key: ValueKey('route_group_row_${entry.ride.rideId}'),
      selected: selected,
      selectedTileColor: colors.primaryContainer,
      selectedColor: colors.onPrimaryContainer,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Text(formatRideDate(entry.ride.date, locale: locale)),
      subtitle: Text(
        '${formatShortDistanceKm(stats.distanceMetres, locale: locale)} · '
        '${formatDuration(stats.durationMs)} · '
        'Ø ${stats.avgSpeedKmh.round()} km/h',
      ),
      trailing: best
          ? Icon(
              Icons.emoji_events,
              color: colors.primary,
              semanticLabel: l10n.a11yBestTime,
            )
          : null,
      onTap: () => onTap(entry),
    );
  }
}
