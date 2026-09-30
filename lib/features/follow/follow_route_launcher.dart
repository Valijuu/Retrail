import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/stacked_dialog_actions.dart';
import '../../domain/heading.dart' show LatLng;
import '../../domain/route_progress.dart';
import '../../l10n/app_localizations.dart';
import '../../tracking/location_permission.dart';
import '../../tracking/tracking_providers.dart';
import '../home/ride_start_flow.dart';
import '../shell/routes.dart';
import 'route_follow_providers.dart';

enum _FollowChoice { record, followOnly }

/// Starts following [reference] (Spec 17): asks whether to record, then either
/// runs the normal ride start (countdown → ride, with the reference) or opens
/// the follow-only screen. While a ride is already recording it just returns
/// to that ride, without a reference. A [reference] without a real route (under
/// 2 points, or no length) is explained in a dialog instead — this is the single
/// place that decides followability.
Future<void> launchFollowRoute(
  BuildContext context,
  WidgetRef ref, {
  required List<LatLng> reference,
  String? rideTitle,
}) async {
  final l10n = AppLocalizations.of(context);
  if (reference.length < 2 || RouteTrack(reference).lengthM <= 0) {
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(l10n.followRouteUnavailableTitle),
        content: Text(l10n.followRouteUnavailableBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(l10n.actionClose),
          ),
        ],
      ),
    );
    return;
  }
  if (ref.read(isTrackingProvider)) {
    context.go(AppRoutes.ride);
    return;
  }
  final choice = await showDialog<_FollowChoice>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(l10n.followRouteRecordTitle),
      content: Text(l10n.followRouteRecordBody),
      actions: [
        StackedDialogActions(
          primaryLabel: l10n.followRouteRecordConfirm,
          onPrimary: () => Navigator.pop(c, _FollowChoice.record),
          secondaryLabel: l10n.followRouteJustFollow,
          onSecondary: () => Navigator.pop(c, _FollowChoice.followOnly),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;
  final follow = ref.read(routeFollowProvider.notifier);
  switch (choice) {
    case _FollowChoice.record:
      await runRideStartFlow(
        context,
        ref,
        beforeCountdown: () => follow.start(
          reference: reference,
          rideTitle: rideTitle,
          recording: true,
        ),
      );
    case _FollowChoice.followOnly:
      final action = await ref.read(rideRecordingControllerProvider).prepare();
      if (!context.mounted) return;
      if (action != LocationStartAction.proceed) {
        await showPermissionGateBlocked(context, ref, action);
        return;
      }
      follow.start(
        reference: reference,
        rideTitle: rideTitle,
        recording: false,
      );
      context.go(AppRoutes.follow);
  }
}
