import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../domain/formatters.dart';
import '../../../domain/route_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../active_ride/widgets/ride_chrome.dart';

/// "X km to go" strip above the ride panel while following (Spec 17).
class FollowRemainingLine extends StatelessWidget {
  const FollowRemainingLine({super.key, required this.progress});

  final RouteProgress? progress;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final locale = Localizations.localeOf(context).toString();
    final p = progress;
    final label = p == null
        ? ''
        : p.isFinished
            ? l10n.followFinished
            : l10n.followRemaining(formatDistanceKm(p.remainingM, locale: locale));
    return Container(
      width: double.infinity,
      color: colors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(label,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .labelLarge
              ?.copyWith(color: colors.onSurface)),
    );
  }
}

/// The follow banner: "X to the route" before the rider has joined, "Off
/// route" after leaving it, otherwise none.
Widget? followBanner(BuildContext context, RouteProgress? progress) {
  if (progress == null || !progress.isOffRoute) return null;
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  return RideWarningBanner(
    label: progress.hasJoined
        ? l10n.followOffRouteBanner
        : l10n.followDistanceToRoute(
            formatDistanceToRoute(progress.offsetM, locale: locale)),
  );
}
