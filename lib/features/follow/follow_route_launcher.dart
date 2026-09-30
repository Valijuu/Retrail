import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/stacked_dialog_actions.dart';
import '../../domain/heading.dart' show LatLng;
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
/// to that ride, without a reference.
Future<void> launchFollowRoute(
  BuildContext context,
  WidgetRef ref, {
  required List<LatLng> reference,
  String? rideTitle,
}) async {
  if (reference.length < 2) return;
  if (ref.read(isTrackingProvider)) {
    context.go(AppRoutes.ride);
    return;
  }
  final l10n = AppLocalizations.of(context);
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
