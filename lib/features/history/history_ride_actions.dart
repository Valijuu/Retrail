import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Ride, Trackpoint;
import '../../data/db/followed_route.dart' show RouteRoot;
import '../../data/db/ride_with_trackpoints.dart';
import '../../data/repositories/data_providers.dart';
import '../../domain/ride_stats.dart';
import '../follow/follow_route_launcher.dart';
import 'history_items.dart';
import 'history_providers.dart';
import 'history_screen.dart';
import 'ride_detail_dialog.dart';
import 'route_group_providers.dart';
import 'widgets/route_group_sheet.dart';

/// What a History ride opens: its detail, its route group's comparison and
/// "Follow route" (Specs 17, 20).
mixin HistoryRideActions on ConsumerState<HistoryScreen> {
  /// Fetches this ride's trackpoints on demand — the list itself doesn't have
  /// them (issue #21) — then opens the read-only detail dialog.
  Future<void> openDetail(RideEntryItem entry) async {
    final ride = entry.ride;
    final tps = await ref
        .read(trackpointRepositoryProvider)
        .getForRide(ride.rideId)
        .first;
    // Spec 20: a follow links to its original, an original to its group.
    final originalId = ride.followedRideId;
    final original = originalId == null
        ? null
        : await ref.read(rideRepositoryProvider).findById(originalId);
    final followCount = ref.read(followCountsProvider).value?[ride.rideId] ?? 0;
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      // Faster than the Material default (150ms): the dialog opens from a
      // direct tap on the preview, so it should feel instant.
      animationStyle: const AnimationStyle(
        duration: Duration(milliseconds: 90),
      ),
      builder: (_) => RideDetailDialog(
        rwt: RideWithTrackpoints(ride: entry.ride, trackpoints: tps),
        stats: entry.stats,
        onDismiss: () => Navigator.of(context).pop(),
        onFollowRoute: () {
          Navigator.of(context).pop();
          followRoute(entry.ride, tps);
        },
        followedFrom: original,
        onOpenOriginal: original == null
            ? null
            : () {
                Navigator.of(context).pop();
                openDetail(
                  RideEntryItem(
                    original,
                    storedRideStats(original) ??
                        statsWithoutTrackpoints(original),
                  ),
                );
              },
        followCount: followCount,
        onOpenGroup: () {
          Navigator.of(context).pop();
          openRouteGroup(entry);
        },
      ),
    );
  }

  /// The comparison of [entry]'s route group, [entry] selected (Spec 20).
  Future<void> openRouteGroup(RideEntryItem entry) => showRouteGroupSheet(
    context,
    rootId: entry.ride.routeRootId,
    highlightRideId: entry.ride.rideId,
    onOpenRide: openDetail,
  );

  /// Loads [ride]'s route and starts "Follow route" for it (Spec 17). A
  /// repeat is followed along its original (Spec 20); [trackpoints], when
  /// given, are [ride]'s own.
  Future<void> followRoute(Ride ride, [List<Trackpoint>? trackpoints]) async {
    final source = await ref.read(historyControllerProvider).followSource(ride);
    final tps = source.rideId == ride.rideId && trackpoints != null
        ? trackpoints
        : await ref
              .read(trackpointRepositoryProvider)
              .getForRide(source.rideId)
              .first;
    if (!mounted) return;
    await launchFollowRoute(
      context,
      ref,
      reference: [for (final tp in tps) (lat: tp.latitude, lng: tp.longitude)],
      rideTitle: source.description,
      sourceRideId: source.rideId,
    );
  }
}
