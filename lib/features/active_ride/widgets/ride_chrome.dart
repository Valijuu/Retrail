import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../domain/activity_type.dart';
import '../../../l10n/app_localizations.dart';
import '../../../map/live_map.dart';
import '../../../tracking/ride_tracking_state.dart';
import '../../onboarding/activity_type_ui.dart';
import '../../../core/theme/theme_context.dart';

// Chrome (app bar + map backdrop) uses the original's fixed dark palette,
// independent of theme — like the countdown. The stats panel + dialogs below
// use the theme-resolved AppColors.
const rideChromeBg = AppColors.dark; // DarkSurface
const rideChromeAccent = AppColors.light; // hint / surface / liveIndicator

/// The active ride's app bar: back, activity glyph, title, Live/Paused badge.
class RideAppBar extends StatelessWidget {
  const RideAppBar(
      {super.key,
      required this.state,
      required this.showLive,
      required this.onBack});

  final RideTrackingState state;

  /// Whether to show the Live/Paused badge. Kept true while the summary dialog
  /// is open (isTracking already flipped false), so the chrome doesn't change
  /// behind the dialog.
  final bool showLive;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final activity = state.activityType ?? ActivityType.defaultType;
    return Container(
      color: rideChromeBg.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: rideChromeAccent.hintText,
            tooltip: l10n.a11yBack,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: activity.glyph(size: 20, color: rideChromeAccent.hintText),
          ),
          Expanded(
            child: Text(l10n.mapActiveRideTitle,
                style:
                    text.titleMedium?.copyWith(color: rideChromeAccent.surface)),
          ),
          if (showLive)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: LiveBadge(isPaused: state.isPaused),
            ),
        ],
      ),
    );
  }
}

/// Dot + "Live"/"Paused" label shown in the app bar while recording.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.isPaused});

  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color =
        isPaused ? rideChromeAccent.hintText : rideChromeAccent.liveIndicator;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(isPaused ? l10n.mapPausedBadge : l10n.mapLiveBadge,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color)),
      ],
    );
  }
}

/// Full-width amber banner shown while recording without a network.
class RideWarningBanner extends StatelessWidget {
  const RideWarningBanner({super.key, required this.label, this.onTap});

  final String label;

  /// Optional action (e.g. open the location settings); the whole strip is
  /// the tap target.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // editActionText (#92400E) is the original banner amber — no new hex.
    // Text takes its paired editActionBg: fixed white was unreadable on the
    // light amber the dark theme uses for the fill.
    final colors = context.colors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        color: colors.editActionText,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.center,
        child: Text(label,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: colors.editActionBg)),
      ),
    );
  }
}

/// The live map plus its exit mask and recenter control.
class RideMapArea extends StatelessWidget {
  const RideMapArea({
    super.key,
    required this.state,
    required this.isFollowing,
    required this.masked,
    required this.onGesture,
    required this.onRecenter,
  });

  final RideTrackingState state;
  final bool isFollowing;

  /// True while the screen is leaving: COVERS the native map with the flat
  /// terrain color so the route's exit transition animates only Flutter
  /// widgets (platform views can't fade and jank when transformed). The map
  /// itself stays mounted — REMOVING the hybrid-composition view mid-exit
  /// forces Android to recomposite its surfaces, which flashed stale surface
  /// content (the timer/ride frame those surfaces last held). Disposal happens
  /// with the route, after home fully covers the screen.
  final bool masked;
  final VoidCallback onGesture;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final loc = state.location;
    final current =
        loc != null ? (lat: loc.latitude, lng: loc.longitude) : null;
    return Stack(
      children: [
        Positioned.fill(
          child: LiveMap(
            points: state.trackPoints,
            current: current,
            isFollowing: isFollowing,
            activityType: state.activityType,
            onGesture: onGesture,
            // The compass stacks right above the recenter button below.
            compassClearance: kMapControlSize + kMapControlInset,
          ),
        ),
        if (masked)
          Positioned.fill(child: ColoredBox(color: colors.mapTerrain)),
        if (!masked && !isFollowing)
          Positioned(
            left: kMapControlInset,
            bottom: kMapControlInset,
            child: FloatingActionButton.small(
              onPressed: onRecenter,
              // Sits ON the map (which follows the app theme), so it matches
              // the map's compass (live_map.dart's _CompassButton) rather than
              // the fixed-palette app bar: a round app-surface button with a
              // primary icon, in light and dark mode alike.
              backgroundColor: colors.surface,
              foregroundColor: colors.primary,
              shape: const CircleBorder(),
              tooltip: l10n.mapRecenterCd,
              child: const Icon(Icons.refresh),
            ),
          ),
      ],
    );
  }
}
