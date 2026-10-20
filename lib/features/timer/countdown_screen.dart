import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_shapes.dart';
import '../../core/widgets/status_bar_style.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/ride_recording_controller.dart';
import '../../tracking/tracking_providers.dart';
import '../home/home_providers.dart';
import '../shell/routes.dart';
import 'countdown_timer.dart';
import 'widgets/countdown_chips.dart';
import 'widgets/countdown_gps_status_row.dart';
import 'widgets/countdown_palette.dart';
import 'widgets/countdown_ring.dart';

/// Pre-ride countdown. Ports `TimerPage`: an animated 10→0 ring, the read-only
/// activity chip, a +5 action, a live GPS-signal row (#69) and a Start-now
/// button.
/// Reaching 0 (or Start now) begins the ride and navigates to the active-ride
/// screen.
///
/// The recording is armed (service + GPS feed) as soon as this opens, while
/// the app is surely in front, and the ride begins at 0 before navigating —
/// so pocketing the phone during the countdown still records (#77).
///
/// Always rendered in the original's fixed palette — dark surfaces with
/// light-theme accents — independent of the app's current theme.
class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key});

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends ConsumerState<CountdownScreen> {
  final CountdownTimer _timer = CountdownTimer();
  int _total = CountdownTimer.defaultSeconds;
  bool _navigated = false;

  /// Set once [RideRecordingController.beginArmedRide] returned — until then
  /// leaving must still disarm (Start now, then back at once).
  bool _begun = false;
  late final RideRecordingController _recording;

  @override
  void initState() {
    super.initState();
    _recording = ref.read(rideRecordingControllerProvider);
    unawaited(_recording.arm());
    _timer.addListener(_onTick);
    _timer.start();
  }

  void _onTick() {
    if (!mounted) return;
    // Stop from the notification during the countdown: leave right away.
    if (_recording.armCancelled && !_navigated) {
      _navigated = true;
      _begun = true; // already torn down by the stop
      _timer.stop();
      context.go(AppRoutes.main);
      return;
    }
    setState(() {
      if (_timer.value > _total) _total = _timer.value;
    });
    if (_timer.isFinished) _goToRide();
  }

  Future<void> _goToRide() async {
    if (_navigated) return;
    _navigated = true;
    _timer.stop();
    // Before navigating: in the background no frame builds the ride screen,
    // so the ride must not wait for it. False = a notification Stop
    // cancelled the start meanwhile.
    final proceed = await _recording.beginArmedRide();
    _begun = true;
    if (!mounted) return;
    context.go(proceed ? AppRoutes.ride : AppRoutes.main);
  }

  @override
  void dispose() {
    if (!_begun) unawaited(_recording.disarm());
    _timer.removeListener(_onTick);
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final activity =
        ref.watch(lastActivityTypeProvider).asData?.value ??
        ActivityType.defaultType;
    // The ring shows the current second draining: while the digit reads N it
    // sweeps from N/total down to (N-1)/total, so it is empty exactly when the
    // count hits 0 (sweeping to N/total instead lagged a second behind and
    // left a fifth of the ring standing at 0).
    final value = _timer.value;
    final ringFrom = _total > 0 ? value / _total : 0.0;
    final ringTo = _total > 0 && value > 0 ? (value - 1) / _total : 0.0;

    return DarkChromeStatusBar(
      child: Scaffold(
        backgroundColor: countdownSurface.surface,
        body: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Stack(
            children: [
              // Fill the width (so the column centres on screen, not just within
              // its own shrink-wrapped width) and reserve the bottom 180 for the
              // GPS row + Start button, centring the countdown in what's left.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                bottom: 180,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.timerGetReady,
                        style: text.labelMedium?.copyWith(
                          color: countdownAccent.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CountdownActivityChip(activity: activity),
                      const SizedBox(height: 32),
                      CountdownRing(from: ringFrom, to: ringTo, value: value),
                      const SizedBox(height: 20),
                      CountdownAddTimeChip(
                        label: l10n.timerAddFiveSec,
                        onTap: () => _timer.addTime(5),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        l10n.timerTagline,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                          color: countdownAccent.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CountdownGpsStatusRow(),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: FilledButton(
                            onPressed: _goToRide,
                            style: FilledButton.styleFrom(
                              backgroundColor: countdownAccent.primary,
                              foregroundColor: countdownAccent.onPrimary,
                              // On the button style, not the Text: the
                              // theme's titleMedium color would override
                              // foregroundColor (and follow the app theme).
                              textStyle: text.titleMedium,
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppShapes.pill,
                              ),
                            ),
                            child: Text(l10n.timerStartNow),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
