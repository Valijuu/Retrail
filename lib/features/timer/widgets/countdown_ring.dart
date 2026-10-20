import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'countdown_palette.dart';

class CountdownRing extends StatelessWidget {
  const CountdownRing({
    super.key,
    required this.from,
    required this.to,
    required this.value,
  });

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
                track: countdownSurface.surfaceContainer,
                arc: countdownAccent.primary,
              ),
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
            child: Text(
              '$value',
              key: ValueKey(value),
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                color: countdownAccent.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.arc,
  });
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
