import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/connectivity/connectivity_providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../domain/formatters.dart';
import '../../l10n/app_localizations.dart';
import '../../map/live_map.dart';
import '../../tracking/location_permission.dart';
import '../../tracking/permission_gate_dialog.dart';
import '../../tracking/ride_recording_controller.dart';
import '../../tracking/ride_tracking_state.dart';
import '../../tracking/tracking_providers.dart';
import '../onboarding/activity_type_ui.dart';
import '../shell/routes.dart';
import '../shell/startup_provider.dart';
import 'active_ride_controller.dart';
import 'active_ride_providers.dart';
import 'max_speed.dart';
import 'ride_dialogs.dart';

// Chrome (app bar + map backdrop) uses the original's fixed dark palette,
// independent of theme — like the countdown. The stats panel + dialogs below
// use the theme-resolved AppColors.
const _chromeBg = AppColors.dark; // DarkSurface
const _chromeAccent = AppColors.light; // hint / surface / liveIndicator

/// The live active-ride screen. Ports `MapPage` + `MapViewModel`: live map +
/// route, Live/Paused badge, offline banner, 2×2 live stats with pause/stop,
/// recenter FAB, and the stop/discard/summary dialogs. Starts the ride on
/// entry and, on save, triggers the preview snapshot.
///
/// The platform GPS source, foreground service and permission gate are Spec 5
/// Part B (device-gated); this screen drives the pure-Dart `RideTracker`.
class ActiveRideScreen extends ConsumerStatefulWidget {
  const ActiveRideScreen({super.key});

  @override
  ConsumerState<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends ConsumerState<ActiveRideScreen> {
  // Captured once so dispose() (and callbacks) never call `ref.read` after the
  // element is defunct.
  late final ActiveRideController _controller;
  late final RideRecordingController _recording;
  bool _hasInitiatedStart = false;
  LocationStartAction? _gateBlock; // non-proceed gate outcome → show a prompt
  bool _rideWasActive = false;
  bool _isFollowing = true;
  double _maxSpeedKmh = 0;
  bool _discardOnDispose = false;
  bool _showConfirmStop = false;
  bool _showDiscardConfirm = false;
  bool _showSummary = false;

  bool get _anyDialogOpen =>
      _showConfirmStop || _showDiscardConfirm || _showSummary;

  @override
  void initState() {
    super.initState();
    // Capture both controllers eagerly so dispose() never calls ref.read after
    // the element is unmounted.
    _controller = ref.read(activeRideControllerProvider);
    _recording = ref.read(rideRecordingControllerProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // A pending deep-link is now consumed (mirrors the old RidePlaceholder).
      ref.read(pendingRideDeepLinkProvider.notifier).state = false;
      // Start the ride once per screen session, gated on location permission +
      // services (Spec 5B). A non-proceed outcome surfaces a prompt instead of a
      // silent no-GPS ride. The gate guards an already-active ride (reopen).
      if (!_hasInitiatedStart) {
        _hasInitiatedStart = true;
        _startGated();
      }
    });
  }

  Future<void> _startGated() async {
    final action = await _recording.start();
    if (!mounted || action == LocationStartAction.proceed) return;
    setState(() => _gateBlock = action);
  }

  @override
  void dispose() {
    if (_discardOnDispose) {
      // Tear down the source + foreground service (single owner) before the
      // ride is discarded, so no zombie notification / background GPS lingers.
      _recording.stop();
      _controller.discardRide();
    }
    super.dispose();
  }

  void _goHome() {
    // Consume any pending-ride deep-link latch before leaving. It is set when
    // the ride notification body is tapped and only cleared on a *fresh* mount
    // (initState); if it was (re)set while we were already on this screen, the
    // router's `pendingRide → /ride` redirect would bounce us straight back here
    // (starting a new ride → stuck on the ride screen). Clearing it first lets
    // the navigation home actually take.
    ref.read(pendingRideDeepLinkProvider.notifier).state = false;
    context.go(AppRoutes.main);
  }

  void _onBack() {
    final tracking =
        ref.read(rideTrackingStateProvider).asData?.value.isTracking ?? false;
    if (tracking) {
      setState(() => _showDiscardConfirm = true);
    } else {
      _goHome();
    }
  }

  void _onStateChange(RideTrackingState state) {
    final m = nextMaxSpeed(
      current: _maxSpeedKmh,
      speedKmh: state.speedKmh,
      isTracking: state.isTracking,
      isPaused: state.isPaused,
    );
    if (m != _maxSpeedKmh) setState(() => _maxSpeedKmh = m);
    if (state.isTracking && !_rideWasActive) _rideWasActive = true;
    if (shouldNavigateHomeOnStop(
      rideWasActive: _rideWasActive,
      isTracking: state.isTracking,
      anyDialogOpen: _anyDialogOpen,
    )) {
      _goHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(rideTrackingStateProvider, (_, next) {
      final state = next.asData?.value;
      if (state != null) _onStateChange(state);
    });

    final state =
        ref.watch(rideTrackingStateProvider).asData?.value ?? const RideTrackingState();
    final isOnline = ref.watch(isOnlineProvider).asData?.value ?? true;
    final l10n = AppLocalizations.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: _chromeBg.surface,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _AppBar(
                    state: state,
                    onBack: _onBack,
                  ),
                  if (!isOnline) _OfflineBanner(label: l10n.mapOfflineBanner),
                  Expanded(
                    flex: state.isTracking ? 65 : 100,
                    child: _MapArea(
                      state: state,
                      isFollowing: _isFollowing,
                      onGesture: () {
                        if (_isFollowing) setState(() => _isFollowing = false);
                      },
                      onRecenter: () => setState(() => _isFollowing = true),
                    ),
                  ),
                  if (state.isTracking)
                    Expanded(
                      flex: 35,
                      child: _RideStatsPanel(
                        state: state,
                        maxSpeedKmh: _maxSpeedKmh,
                        onPauseResume: () =>
                            _controller.pauseOrResume(state.isPaused),
                        onStop: () => setState(() => _showConfirmStop = true),
                      ),
                    ),
                ],
              ),
            ),
            if (_showConfirmStop)
              ConfirmStopDialog(
                onDismiss: () => setState(() => _showConfirmStop = false),
                onConfirm: () {
                  setState(() {
                    _showConfirmStop = false;
                    _showSummary = true;
                  });
                  _recording.stop();
                },
              ),
            if (_showDiscardConfirm)
              DiscardRideConfirmDialog(
                onDismiss: () => setState(() => _showDiscardConfirm = false),
                onConfirm: () {
                  setState(() {
                    _showDiscardConfirm = false;
                    _discardOnDispose = true;
                  });
                  _goHome();
                },
              ),
            if (_showSummary)
              PostRideSummaryDialog(
                onSkip: () {
                  setState(() => _showSummary = false);
                  _goHome();
                },
                onSave: (title, comment, favorite) {
                  setState(() => _showSummary = false);
                  _controller.saveRide(
                    title: title,
                    comment: comment,
                    favorite: favorite,
                  );
                  _goHome();
                },
                onDiscard: () {
                  setState(() => _showSummary = false);
                  _controller.discardRide();
                  _goHome();
                },
              ),
            if (_gateBlock != null)
              PermissionGateDialog(
                action: _gateBlock!,
                onOpenSettings: () {
                  final block = _gateBlock!;
                  setState(() => _gateBlock = null);
                  block == LocationStartAction.openLocationSettings
                      ? _recording.openLocationSettings()
                      : _recording.openAppSettings();
                  _goHome();
                },
                onDismiss: () {
                  setState(() => _gateBlock = null);
                  _goHome();
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar({required this.state, required this.onBack});

  final RideTrackingState state;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final activity = state.activityType ?? ActivityType.defaultType;
    return Container(
      color: _chromeBg.surface,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            color: _chromeAccent.hintText,
            tooltip: l10n.a11yBack,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: activity.glyph(size: 20, color: _chromeAccent.hintText),
          ),
          Expanded(
            child: Text(l10n.mapActiveRideTitle,
                style: text.titleMedium?.copyWith(color: _chromeAccent.surface)),
          ),
          if (state.isTracking)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _LiveBadge(isPaused: state.isPaused),
            ),
        ],
      ),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.isPaused});

  final bool isPaused;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final color =
        isPaused ? _chromeAccent.hintText : _chromeAccent.liveIndicator;
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

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // editActionText (#92400E) is the original banner amber — no new hex.
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      width: double.infinity,
      color: colors.editActionText,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      alignment: Alignment.center,
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall
              ?.copyWith(color: Colors.white)),
    );
  }
}

class _MapArea extends StatelessWidget {
  const _MapArea({
    required this.state,
    required this.isFollowing,
    required this.onGesture,
    required this.onRecenter,
  });

  final RideTrackingState state;
  final bool isFollowing;
  final VoidCallback onGesture;
  final VoidCallback onRecenter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          ),
        ),
        if (!isFollowing)
          Positioned(
            left: 12,
            bottom: 12,
            child: FloatingActionButton.small(
              onPressed: onRecenter,
              backgroundColor: Colors.white,
              foregroundColor: _chromeBg.surface,
              tooltip: l10n.mapRecenterCd,
              child: const Icon(Icons.refresh),
            ),
          ),
      ],
    );
  }
}

class _RideStatsPanel extends StatelessWidget {
  const _RideStatsPanel({
    required this.state,
    required this.maxSpeedKmh,
    required this.onPauseResume,
    required this.onStop,
  });

  final RideTrackingState state;
  final double maxSpeedKmh;
  final VoidCallback onPauseResume;
  final VoidCallback onStop;

  String _kmh(double? v) => v == null ? '-- km/h' : '${v.toStringAsFixed(1)} km/h';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final speed = state.speedKmh;
    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            width: 24,
            height: 3,
            decoration: BoxDecoration(
                color: colors.surfaceContainer,
                borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatSpeed,
                    value: _kmh(speed),
                    valueColor: (speed ?? 0) > 0 ? colors.primary : colors.onSurface,
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatDistance,
                    value: '${(state.distanceMetres / 1000.0).toStringAsFixed(2)} km',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatDuration,
                    value: formatElapsed(state.elapsedSeconds),
                  ),
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: _StatCell(
                    label: l10n.mapStatMaxSpeed,
                    value: _kmh(maxSpeedKmh),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: state.isPaused ? l10n.mapResumeRide : l10n.mapPauseRide,
                  filled: state.isPaused,
                  onTap: onPauseResume,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ActionButton(
                  label: l10n.mapStopRide,
                  filled: false,
                  onTap: onStop,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  const _StatCell({required this.label, required this.value, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
          color: colors.surfaceContainer, borderRadius: AppShapes.input),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      alignment: Alignment.centerLeft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
          Text(value,
              style: text.titleMedium
                  ?.copyWith(color: valueColor ?? colors.onSurface)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.filled,
    required this.onTap,
  });

  final String label;
  final bool filled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final style = ButtonStyle(
      shape: const WidgetStatePropertyAll(
          RoundedRectangleBorder(borderRadius: AppShapes.pill)),
      backgroundColor:
          WidgetStatePropertyAll(filled ? colors.primary : colors.surface),
      foregroundColor:
          WidgetStatePropertyAll(filled ? colors.onPrimary : colors.primary),
      side: filled
          ? null
          : WidgetStatePropertyAll(BorderSide(color: colors.surfaceContainer, width: 1.5)),
    );
    return TextButton(
      onPressed: onTap,
      style: style,
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}
