import 'package:flutter/material.dart';

import '../../core/theme/app_shapes.dart';
import '../../domain/formatters.dart';
import '../../l10n/app_localizations.dart';
import 'recent_ride_ui.dart';
import '../../core/theme/theme_context.dart';

/// Compact recent-ride / favorite row: place icon, title + date, optional
/// favorite heart, distance, and a navigate-to-start button when a route exists.
class RideRowCard extends StatelessWidget {
  const RideRowCard({
    super.key,
    required this.ride,
    required this.onTap,
    this.showFavorite = false,
    this.onNavigate,
  });

  final RecentRideUi ride;
  final VoidCallback onTap;
  final bool showFavorite;
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final canNavigate = ride.hasRoute && ride.startLat != null && ride.startLng != null;

    return Material(
      color: colors.surfaceContainer,
      borderRadius: AppShapes.card,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShapes.card,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: colors.surface, borderRadius: AppShapes.input),
                child: Icon(Icons.place,
                    size: 16,
                    color: ride.hasRoute ? colors.primary : colors.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ride.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyLarge?.copyWith(
                            color: colors.onSurface, fontWeight: FontWeight.w500)),
                    Text(ride.dateTime,
                        style: text.bodySmall?.copyWith(color: colors.subtleText)),
                  ],
                ),
              ),
              if (showFavorite) ...[
                const SizedBox(width: 10),
                Icon(Icons.favorite, size: 18, color: colors.primary),
              ],
              const SizedBox(width: 10),
              Text('${formatDecimal(ride.distanceKm, 1, locale: locale)} km',
                  style: text.bodyLarge?.copyWith(
                      color: colors.primary, fontWeight: FontWeight.w500)),
              if (canNavigate) ...[
                const SizedBox(width: 10),
                Semantics(
                  button: true,
                  label: l10n.a11yNavigateToStart,
                  child: GestureDetector(
                    onTap: onNavigate,
                    child: Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration:
                          BoxDecoration(color: colors.surface, shape: BoxShape.circle),
                      child: Icon(Icons.directions, size: 18, color: colors.primary),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
