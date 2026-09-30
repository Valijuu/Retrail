import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../domain/formatters.dart';
import '../../../domain/route_progress.dart';
import '../../../l10n/app_localizations.dart';
import '../../active_ride/widgets/ride_chrome.dart';

/// The follow progress text: "X km to go" (with "· reversed" when the route
/// is ridden backwards, Spec 18) or "Finish reached". A null [progress]
/// (before the first fix, or while the direction is undecided) shows the
/// whole route's length [totalM].
String followProgressLabel(BuildContext context,
    {required RouteProgress? progress,
    required double totalM,
    bool reversed = false}) {
  final l10n = AppLocalizations.of(context);
  final locale = Localizations.localeOf(context).toString();
  final p = progress;
  if (p != null && p.isFinished) return l10n.followFinished;
  final distance =
      formatDistanceKm(p == null ? totalM : p.remainingM, locale: locale);
  return reversed
      ? l10n.followRemainingReversed(distance)
      : l10n.followRemaining(distance);
}

/// "X km to go" strip under the ride map while following (Spec 17).
/// Before the first fix it shows the whole route's length.
class FollowRemainingLine extends StatelessWidget {
  const FollowRemainingLine(
      {super.key,
      required this.progress,
      required this.totalM,
      this.reversed = false});

  final RouteProgress? progress;

  /// The followed route's length, shown while [progress] is still null.
  final double totalM;

  /// The route is ridden backwards: the text says so (Spec 18).
  final bool reversed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      color: colors.surfaceContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Text(
          followProgressLabel(context,
              progress: progress, totalM: totalM, reversed: reversed),
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
