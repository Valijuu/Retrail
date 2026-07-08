import 'dart:async' show unawaited;

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
  bool _showConfirmStop = false;
  bool _showDiscardConfirm = false;
  bool _showSummary = false;

  /// True from the moment a summary action (save/skip/discard) starts the
  /// navigation home until this screen is disposed. Keeps the ride chrome
  /// frozen and a scrim up during the exit transition — closing the dialog
  /// used to collapse the stats panel + re-expand the map for a few frames
  /// (visible flicker) before the pop-to-home animation began.
  bool _isLeaving = false;

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

  void _goHome() {
    // Navigate exactly ONCE per screen session: this can be re-entered (a
    // summary action + the shouldNavigateHomeOnStop listener), and a second
    // pages update while the exit transition is in flight destabilizes the
    // Navigator's page handshake.
    if (_isLeaving) return;
    // Cover the native map with its terrain placeholder before the exit
    // transition starts: platform views ignore opacity and transform
    // expensively, so fading/scaling the live map janked the pop-to-home
    // animation. With the map covered, the transition animates only Flutter
    // widgets and runs smoothly (mirrors the entry, where the placeholder
    // covers the map until its style loads).
    if (mounted) setState(() => _isLeaving = true);
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
    // Back with a dialog open dismisses THAT dialog — it used to stack the
    // discard dialog on top of the stop dialog, leaving the stop dialog
    // orphaned on screen through the discard-exit. The summary is
    // deliberately non-dismissible (its own buttons decide the ride's fate).
    if (_showConfirmStop) {
      setState(() => _showConfirmStop = false);
      return;
    }
    if (_showDiscardConfirm) {
      setState(() => _showDiscardConfirm = false);
      return;
    }
    if (_showSummary) return;
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

  /// Overlays [dialog] on a scrim that swallows every tap/gesture, like a real
  /// `showDialog` barrier. The dialogs live in this screen's Stack (not a
  /// Navigator route), so without this the map, stop/pause buttons and back
  /// arrow behind them stayed clickable.
  ///
  /// Keyboard: the Scaffold has `resizeToAvoidBottomInset: false` (the ride
  /// chrome must not squeeze), and [Dialog] pads itself by
  /// `MediaQuery.viewInsets` — so the dialog rises above the keyboard on its
  /// own. Do NOT add another inset padding here: doubling it shoved the dialog
  /// half off-screen and made it untappable.
  Widget _modal(Widget dialog) => Positioned.fill(
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ModalBarrier(dismissible: false, color: Colors.black54),
            // SafeArea: the overlay Stack spans the whole screen (unlike the
            // chrome, which sits in its own SafeArea) — without it the dialog
            // slid up under the status bar when the keyboard squeezed it.
            SafeArea(child: dialog),
          ],
        ),
      );

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

    // The Live/Paused badge reflects (or freezes) the tracking state: kept up
    // while the summary dialog is open and through the exit transition —
    // stopping flips isTracking false BEFORE the dialog closes, and nothing
    // behind the dialog may change.
    final showLive = state.isTracking || _showSummary || _isLeaving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: _chromeBg.surface,
        // Don't squeeze the map + stats layout when the keyboard opens for the
        // summary dialog's inputs (it overflowed the panel and resized the
        // native map). The dialog lifts itself above the keyboard in [_modal].
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  _AppBar(
                    state: state,
                    showLive: showLive,
                    onBack: _onBack,
                  ),
                  if (!isOnline) _OfflineBanner(label: l10n.mapOfflineBanner),
                  // The 65/35 map+stats layout is fixed for the whole screen
                  // session: the panel shows from the FIRST frame (zeros/--,
                  // blending in with the screen's entry transition, before GPS
                  // or the tracker have committed) and stays through the stop
                  // dialog + exit transition. Gating it on isTracking made it
                  // pop in late on entry and flicker away on save.
                  Expanded(
                    flex: 65,
                    child: _MapArea(
                      state: state,
                      isFollowing: _isFollowing,
                      masked: _isLeaving,
                      onGesture: () {
                        if (_isFollowing) setState(() => _isFollowing = false);
                      },
                      onRecenter: () => setState(() => _isFollowing = true),
                    ),
                  ),
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
              _modal(ConfirmStopDialog(
                onDismiss: () => setState(() => _showConfirmStop = false),
                onConfirm: () {
                  setState(() {
                    _showConfirmStop = false;
                    _showSummary = true;
                  });
                  _recording.stop();
                },
              )),
            if (_showDiscardConfirm)
              _modal(DiscardRideConfirmDialog(
                onDismiss: () => setState(() => _showDiscardConfirm = false),
                onConfirm: () {
                  setState(() => _showDiscardConfirm = false);
                  // Stop+discard runs now (before navigation) so isTrackingProvider
                  // is false before the home screen becomes interactive. Deferring
                  // this to dispose() left a window during GoRouter's exit animation
                  // where "Start Tracking" could read isTracking=true and skip the
                  // timer. discardActiveRide() is synchronous inside stop(), so the
                  // state flip happens in this call frame.
                  unawaited(_recording.stop(discard: true));
                  _goHome();
                },
              )),
            if (_showSummary)
              _modal(PostRideSummaryDialog(
                // _goHome() flips _isLeaving in the same frame the dialog
                // closes, so the frozen chrome + scrim carry through the exit.
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
              )),
            // Keep the scrim up (dialog gone) while the exit transition plays,
            // so the frozen ride screen fades out dimmed instead of flashing
            // back to life for a few frames.
            if (_isLeaving)
              const Positioned.fill(
                child: ModalBarrier(dismissible: false, color: Colors.black54),
              ),
            if (_gateBlock != null)
              _modal(PermissionGateDialog(
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
              )),
          ],
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  const _AppBar(
      {required this.state, required this.showLive, required this.onBack});

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
          if (showLive)
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
    final colors = Theme.of(context).extension<AppColors>()!;
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
        if (masked)
          Positioned.fill(child: ColoredBox(color: colors.mapTerrain)),
        if (!masked && !isFollowing)
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
