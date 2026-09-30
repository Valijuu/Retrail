import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/stats_aggregation.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/tracking_providers.dart';
import '../follow/route_follow_providers.dart';
import '../profile/profile_providers.dart';
import '../shell/routes.dart';
import 'greetings.dart';
import 'home_providers.dart';
import 'navigation_chooser.dart';
import 'navigation_launcher.dart';
import 'recent_ride_ui.dart';
import 'ride_start_flow.dart';
import 'ride_row_card.dart';
import 'top_header.dart';
import 'weekly_hero_card.dart';
import '../../core/theme/theme_context.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.greetingIndex,
    this.onOpenRide,
    this.onAvatarTap,
  });

  /// Which of the skater greetings to show. Owned by the shell: this screen is
  /// disposed while off-screen, so a greeting picked here re-rolled whenever
  /// Home slid back into view — before the user had arrived.
  final int greetingIndex;
  final void Function(int rideId)? onOpenRide;
  final VoidCallback? onAvatarTap;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Future<void> _start() async {
    if (ref.read(isTrackingProvider)) {
      context.go(AppRoutes.ride);
      return;
    }
    // A normal ride never inherits a reference left over from an abandoned
    // "Follow route → Record" start (e.g. back from the countdown).
    ref.read(routeFollowProvider.notifier).stop();
    await runRideStartFlow(context, ref);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final greetings = skaterGreetings(l10n);
    final template = greetings[widget.greetingIndex.clamp(0, greetings.length - 1)];
    final userName =
        ref.watch(userNameProvider).asData?.value ?? l10n.homeDefaultName;
    final photo = ref.watch(currentProfilePhotoProvider).asData?.value;
    final weekly =
        ref.watch(weeklyStatsProvider).asData?.value ?? const WeeklyStats.zero();
    final daily =
        ref.watch(dailyStatsProvider).asData?.value ?? const WeeklyStats.zero();
    final yearly =
        ref.watch(yearlyStatsProvider).asData?.value ?? const WeeklyStats.zero();
    final statsPeriod =
        ref.watch(homeStatsPeriodProvider).asData?.value ?? StatsPeriod.week;
    final recent = ref.watch(recentRidesProvider).asData?.value ?? const [];
    final favorites = ref.watch(favoriteRidesProvider).asData?.value ?? const [];
    // Keep connectivity subscribed while Home is up, so the Start tap reads a
    // real value: an unwatched provider is paused, and the bare read in
    // [_start] then always saw "loading → online" and never offered the
    // offline confirm (issue #31).
    ref.watch(isOnlineProvider);

    return Scaffold(
      backgroundColor: colors.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 16),
                    TopHeader(
                      greetingTemplate: template,
                      name: userName,
                      photoPath: photo,
                      onAvatarTap: widget.onAvatarTap,
                    ),
                    const SizedBox(height: 16),
                    WeeklyHeroCard(
                      daily: daily,
                      weekly: weekly,
                      yearly: yearly,
                      selected: statsPeriod,
                      onSelect: ref.read(homeControllerProvider).selectStatsPeriod,
                    ),
                    const SizedBox(height: 16),
                    _SectionLabel(l10n.sectionRecentRides),
                    const SizedBox(height: 8),
                    _rideList(recent, l10n.homeEmptyNoRides, showFavorite: false),
                    const SizedBox(height: 16),
                    _SectionLabel(l10n.sectionRecentFavorites),
                    const SizedBox(height: 8),
                    _rideList(favorites, l10n.homeEmptyNoFavorites,
                        showFavorite: true),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _start,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(borderRadius: AppShapes.pill),
                ),
                child: Text(l10n.homeStartTracking),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _rideList(List<RecentRideUi> rides, String emptyText,
      {required bool showFavorite}) {
    if (rides.isEmpty) return _EmptyPlaceholderCard(emptyText);
    return Column(
      children: [
        for (var i = 0; i < rides.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          RideRowCard(
            ride: rides[i],
            showFavorite: showFavorite,
            onTap: () => widget.onOpenRide?.call(rides[i].rideId),
            onNavigate: () => navigateTo(
                context,
                ref.read(navigationLauncherProvider),
                rides[i].startLat!,
                rides[i].startLng!,
                rides[i].title),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Text(text,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: colors.subtleText));
  }
}

class _EmptyPlaceholderCard extends StatelessWidget {
  const _EmptyPlaceholderCard(this.text);
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 36),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
          color: colors.surfaceContainer, borderRadius: AppShapes.card),
      child: Text(text,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colors.onSurfaceVariant, fontStyle: FontStyle.italic)),
    );
  }
}
