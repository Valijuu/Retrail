import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/theme/theme_context.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/ride_tracking_state.dart';
import '../../tracking/tracking_providers.dart';
import '../active_ride/widgets/ride_chrome.dart';
import '../home/navigation_chooser.dart';
import '../home/navigation_launcher.dart';
import '../shell/routes.dart';
import '../../domain/route_progress.dart';
import 'route_follow_providers.dart';
import 'widgets/follow_chrome.dart';

/// Follow-only mode (Spec 17 §E2): the saved route with the rider's live
/// position, remaining distance and off-route banner — nothing is recorded.
/// GPS runs only while the app is in the foreground.
class FollowRouteScreen extends ConsumerStatefulWidget {
  const FollowRouteScreen({super.key});

  @override
  ConsumerState<FollowRouteScreen> createState() => _FollowRouteScreenState();
}

class _FollowRouteScreenState extends ConsumerState<FollowRouteScreen>
    with WidgetsBindingObserver {
  late final RouteFollowNotifier _follow;

  /// The session this screen was opened for; [dispose] pauses only its feed.
  RouteTrack? _session;
  bool _isFollowing = true;
  bool _leaving = false;

  /// Last non-null follow state, kept while leaving so the screen doesn't
  /// blank during the exit transition after `stop()` clears the provider.
  RouteFollowState? _frozen;

  @override
  void initState() {
    super.initState();
    _follow = ref.read(routeFollowProvider.notifier);
    _session = ref.read(routeFollowProvider)?.track;
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(routeFollowProvider) == null) {
        _leave();
      } else {
        _follow.resumeFeed();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _follow.pauseFeed();
    if (state == AppLifecycleState.resumed) _follow.resumeFeed();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Leaving by any route (not only End) must not keep GPS running — but a
    // newer session started during the exit transition keeps its feed (#50).
    final session = _session;
    if (session != null) _follow.pauseFeedFor(session);
    super.dispose();
  }

  void _leave() {
    if (_leaving) return;
    _leaving = true;
    _frozen = ref.read(routeFollowProvider);
    _follow.stop();
    context.go(AppRoutes.main);
  }

  Future<void> _confirmEnd() async {
    final l10n = AppLocalizations.of(context);
    final end = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.followEndConfirmTitle),
        content: Text(l10n.followEndConfirmBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.actionCancel)),
          TextButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.followEndAction)),
        ],
      ),
    );
    if (end == true && mounted) _leave();
  }

  @override
  Widget build(BuildContext context) {
    final follow = ref.watch(routeFollowProvider) ?? (_leaving ? _frozen : null);
    final isOnline = ref.watch(isOnlineProvider).asData?.value ?? true;
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    if (follow == null) return Scaffold(backgroundColor: rideChromeBg.surface);
    final progress = follow.progress;
    final banner = followBanner(context, progress);
    final notJoined = progress == null || !progress.hasJoined;
    final title = follow.rideTitle?.trim();
    final start = follow.track.points.first;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmEnd();
      },
      child: Scaffold(
        backgroundColor: rideChromeBg.surface,
        body: SafeArea(
          child: Column(
            children: [
              Container(
                color: rideChromeBg.surface,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _confirmEnd,
                      icon: const Icon(Icons.arrow_back),
                      color: rideChromeAccent.hintText,
                      tooltip: l10n.a11yBack,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.followRouteTitle,
                              style: text.titleMedium
                                  ?.copyWith(color: rideChromeAccent.surface)),
                          if (title != null && title.isNotEmpty)
                            Text(title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: text.bodySmall
                                    ?.copyWith(color: rideChromeAccent.hintText)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isOnline) RideWarningBanner(label: l10n.mapOfflineBanner),
              if (!follow.locationServiceEnabled)
                RideWarningBanner(
                  label: l10n.followLocationOffBanner,
                  onTap: ref.read(rideRecordingControllerProvider).openLocationSettings,
                ),
              ?banner,
              Expanded(
                child: RideMapArea(
                  state: RideTrackingState(location: follow.lastFix),
                  isFollowing: _isFollowing,
                  masked: _leaving,
                  reference: follow.track,
                  referenceProgressM: progress?.alongM,
                  headingTrail: follow.trail,
                  onGesture: () {
                    if (_isFollowing) setState(() => _isFollowing = false);
                  },
                  onRecenter: () => setState(() => _isFollowing = true),
                ),
              ),
              FollowRemainingLine(
                  progress: progress, totalM: follow.track.lengthM),
              Container(
                color: colors.surface,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: notJoined
                            ? FilledButton.tonalIcon(
                                onPressed: () => navigateTo(
                                    context,
                                    ref.read(navigationLauncherProvider),
                                    start.lat,
                                    start.lng,
                                    (title == null || title.isEmpty)
                                        ? l10n.followRouteTitle
                                        : title),
                                icon: const Icon(Icons.directions),
                                label: Text(l10n.followNavigateToStart),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      onPressed: _confirmEnd,
                      child: Text(l10n.followEndAction),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
