import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import '../home/home_providers.dart';
import '../onboarding/activity_type_ui.dart';
import '../shell/routes.dart';
import 'countdown_timer.dart';

/// Pre-ride countdown. Ports `TimerPage`: an animated 5→0 ring, the read-only
/// activity chip, a +5 action, a static GPS-signal row and a Start-now button.
/// Reaching 0 (or Start now) navigates to the active-ride screen.
///
/// Always rendered in the original's fixed palette — dark surfaces with
/// light-theme accents — independent of the app's current theme.
class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key});

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

// Fixed palette (no theme resolution): dark backgrounds + light-theme accents.
const _surface = AppColors.dark; // backgrounds
const _accent = AppColors.light; // arc, digit, labels, chip text

class _CountdownScreenState extends ConsumerState<CountdownScreen> {
  final CountdownTimer _timer = CountdownTimer();
  int _total = 5;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _timer.addListener(_onTick);
    _timer.start();
  }

  void _onTick() {
    if (!mounted) return;
    setState(() {
      if (_timer.value > _total) _total = _timer.value;
    });
    if (_timer.isFinished) _goToRide();
  }

  void _goToRide() {
    if (_navigated) return;
    _navigated = true;
    _timer.stop();
    context.go(AppRoutes.ride);
  }

  @override
  void dispose() {
    _timer.removeListener(_onTick);
    _timer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final activity = ref.watch(lastActivityTypeProvider).asData?.value ??
        ActivityType.defaultType;
    // The ring shows the current second draining: while the digit reads N it
    // sweeps from N/total down to (N-1)/total, so it is empty exactly when the
    // count hits 0 (sweeping to N/total instead lagged a second behind and
    // left a fifth of the ring standing at 0).
    final value = _timer.value;
    final ringFrom = _total > 0 ? value / _total : 0.0;
    final ringTo = _total > 0 && value > 0 ? (value - 1) / _total : 0.0;

    return Scaffold(
      backgroundColor: _surface.surface,
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
                    Text(l10n.timerGetReady,
                        style: text.labelMedium
                            ?.copyWith(color: _accent.onSurfaceVariant)),
                    const SizedBox(height: 16),
                    _ActivityChip(activity: activity),
                    const SizedBox(height: 32),
                    _CountdownRing(from: ringFrom, to: ringTo, value: value),
                    const SizedBox(height: 20),
                    _AddTimeChip(
                        label: l10n.timerAddFiveSec,
                        onTap: () => _timer.addTime(5)),
                    const SizedBox(height: 28),
                    Text(l10n.timerTagline,
                        textAlign: TextAlign.center,
                        style: text.bodyMedium?.copyWith(
                            color: _accent.onSurfaceVariant, height: 1.5)),
                  ],
                ),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 16, bottom: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _GpsStatusRow(),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: FilledButton(
                          onPressed: _goToRide,
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent.primary,
                            foregroundColor: _accent.onPrimary,
                            // On the button style, not the Text: the
                            // theme's titleMedium color would override
                            // foregroundColor (and follow the app theme).
                            textStyle: text.titleMedium,
                            shape: const RoundedRectangleBorder(
                                borderRadius: AppShapes.pill),
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
    );
  }
}

class _ActivityChip extends StatelessWidget {
  const _ActivityChip({required this.activity});
  final ActivityType activity;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      decoration: BoxDecoration(
          color: _surface.surfaceContainer, borderRadius: AppShapes.pill),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          activity.glyph(size: 18, color: _accent.primaryContainer),
          const SizedBox(width: 8),
          Text(activity.label(l10n),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: _accent.primaryContainer,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _AddTimeChip extends StatelessWidget {
  const _AddTimeChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _surface.surfaceContainer,
      borderRadius: AppShapes.pill,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShapes.pill,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: _accent.primaryContainer, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }
}

class _GpsStatusRow extends StatelessWidget {
  const _GpsStatusRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
          color: _surface.surfaceContainer, borderRadius: AppShapes.input),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: _accent.primary, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(l10n.gpsStatusLabel,
              style:
                  text.labelMedium?.copyWith(color: _accent.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text(l10n.gpsStatusReady,
              style: text.labelMedium?.copyWith(
                  color: _accent.primaryContainer, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _CountdownRing extends StatelessWidget {
  const _CountdownRing(
      {required this.from, required this.to, required this.value});

  /// Sweep at the start of the current second (only used on the first build).
  final double from;

  /// Sweep the ring glides to by the end of the current second.
  final double to;
  final int value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The builder starts at [from] on the first build, then on every
          // tick glides from wherever it is to the new [to] linearly over the
          // 1 s tick, so the arc drains smoothly instead of snapping.
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: from, end: to),
            duration: const Duration(milliseconds: 1000),
            curve: Curves.linear,
            builder: (context, animated, _) => CustomPaint(
              size: const Size.square(180),
              painter: _RingPainter(
                  progress: animated,
                  track: _surface.surfaceContainer,
                  arc: _accent.primary),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            // A continuous "odometer" roll: the old digit drifts UP and fades
            // out while the new one rises in from below — short travel (35% of
            // the digit height), eased, faded. The previous full-height linear
            // slide made the outgoing digit bounce back the way it came, which
            // read as jerky.
            transitionBuilder: (child, anim) {
              final incoming = child.key == ValueKey(value);
              final slide = Tween<Offset>(
                begin: Offset(0, incoming ? 0.35 : -0.35),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: Text('$value',
                key: ValueKey(value),
                style: Theme.of(context)
                    .textTheme
                    .displayMedium
                    ?.copyWith(color: _accent.surface)),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.progress, required this.track, required this.arc});
  final double progress;
  final Color track;
  final Color arc;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final radius = (size.shortestSide - stroke) / 2;
    final center = size.center(Offset.zero);
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(center, radius, trackPaint);

    final arcPaint = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.arc != arc || old.track != track;
}
