import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_shapes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../tracking/gps_signal.dart';
import '../countdown_providers.dart';
import 'countdown_palette.dart';

/// The GPS status from the fixes the armed recording streams (#69): the
/// original's row was static and always said "ready". Display only — the
/// ride still starts at 0 either way.
class CountdownGpsStatusRow extends ConsumerWidget {
  const CountdownGpsStatusRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final signal = ref.watch(countdownGpsSignalProvider);
    final ready = signal == GpsSignal.ready;
    final status = switch (signal) {
      GpsSignal.ready => l10n.gpsStatusReady,
      GpsSignal.searching => l10n.gpsStatusSearching,
      GpsSignal.off => l10n.gpsStatusOff,
    };
    return Container(
      decoration: BoxDecoration(
        color: countdownSurface.surfaceContainer,
        borderRadius: AppShapes.input,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ready
                  ? countdownAccent.primary
                  : countdownAccent.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            l10n.gpsStatusLabel,
            style: text.labelMedium?.copyWith(
              color: countdownAccent.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            status,
            style: text.labelMedium?.copyWith(
              color: ready
                  ? countdownAccent.primaryContainer
                  : countdownAccent.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
