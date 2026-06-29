import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../domain/stats_aggregation.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/location_permission.dart';
import '../../tracking/permission_gate_dialog.dart';
import '../../tracking/tracking_providers.dart';
import '../profile/profile_providers.dart';
import '../shell/routes.dart';
import 'greeting_selector.dart';
import 'greetings.dart';
import 'home_providers.dart';
import 'navigation_launcher.dart';
import 'recent_ride_ui.dart';
import 'ride_row_card.dart';
import 'top_header.dart';
import 'weekly_hero_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    required this.greetingKey,
    this.onOpenRide,
    this.onAvatarTap,
  });

  final int greetingKey;
  final void Function(int rideId)? onOpenRide;
  final VoidCallback? onAvatarTap;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  static const _greetingCount = 15;
  final GreetingSelector _greeting = GreetingSelector();
  late int _greetingIndex = _greeting.next(_greetingCount);

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.greetingKey != widget.greetingKey) {
      setState(() => _greetingIndex = _greeting.next(_greetingCount));
    }
  }

  Future<void> _start() async {
    if (ref.read(isTrackingProvider)) {
      context.go(AppRoutes.ride);
      return;
    }
    final type = ref.read(lastActivityTypeProvider).asData?.value ??
        ActivityType.defaultType;
    ref.read(homeControllerProvider).beginTracking(type);
    final online = ref.read(isOnlineProvider).asData?.value ?? true;
    if (online) {
      await _proceed();
    } else {
      await _confirmOffline();
    }
  }

  /// Resolves location (and notification) permission up front — at the
  /// Start-tracking press, before the countdown — mirroring the original
  /// `HomePage`. Only a granted gate continues to the timer; a blocked gate
  /// surfaces the rationale / enable-location prompt and stays on home.
  Future<void> _proceed() async {
    final action = await ref.read(rideRecordingControllerProvider).prepare();
    if (!mounted) return;
    if (action == LocationStartAction.proceed) {
      context.go(AppRoutes.timer);
    } else {
      await _showGateBlocked(action);
    }
  }

  Future<void> _showGateBlocked(LocationStartAction action) async {
    final recording = ref.read(rideRecordingControllerProvider);
    await showDialog<void>(
      context: context,
      builder: (c) => PermissionGateDialog(
        action: action,
        onOpenSettings: () {
          Navigator.pop(c);
          action == LocationStartAction.openLocationSettings
              ? recording.openLocationSettings()
              : recording.openAppSettings();
        },
        onDismiss: () => Navigator.pop(c),
      ),
    );
  }

  Future<void> _confirmOffline() async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.offlineTrackingTitle),
        content: Text(l10n.offlineTrackingBody),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(l10n.actionSkip)),
          FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(l10n.offlineTrackingConfirm)),
        ],
      ),
    );
    if (confirmed == true) await _proceed();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final greetings = skaterGreetings(l10n);
    final template = greetings[_greetingIndex.clamp(0, greetings.length - 1)];
    final userName =
        ref.watch(userNameProvider).asData?.value ?? l10n.homeDefaultName;
    final photo = ref.watch(currentProfilePhotoProvider).asData?.value;
    final weekly =
        ref.watch(weeklyStatsProvider).asData?.value ?? const WeeklyStats.zero();
    final daily =
        ref.watch(dailyStatsProvider).asData?.value ?? const WeeklyStats.zero();
    final yearly =
        ref.watch(yearlyStatsProvider).asData?.value ?? const WeeklyStats.zero();
    final recent = ref.watch(recentRidesProvider).asData?.value ?? const [];
    final favorites = ref.watch(favoriteRidesProvider).asData?.value ?? const [];

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
                    WeeklyHeroCard(daily: daily, weekly: weekly, yearly: yearly),
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
            onNavigate: () => ref.read(navigationLauncherProvider).launchTo(
                rides[i].startLat!, rides[i].startLng!, rides[i].title),
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
    final colors = Theme.of(context).extension<AppColors>()!;
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
    final colors = Theme.of(context).extension<AppColors>()!;
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
