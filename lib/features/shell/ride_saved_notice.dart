import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart' show Ride;
import '../../data/repositories/data_providers.dart';
import '../../data/repositories/preferences_repository.dart';
import '../../data/repositories/ride_repository.dart';
import '../../l10n/app_localizations.dart';
import '../history/open_edit_ride_sheet.dart';

/// Hands out the ride a notification / Live Activity "Stop" saved without the
/// post-ride summary (#75) — once: taking it clears the parked id, and a ride
/// deleted in the meantime yields null.
class RideSavedNoticeController {
  RideSavedNoticeController(this._prefs, this._rides);

  final PreferencesRepository _prefs;
  final RideRepository _rides;

  Future<Ride?> take() async {
    final rideId = _prefs.pendingRideDetailsNow;
    if (rideId == null) return null;
    await _prefs.setPendingRideDetails(null);
    return _rides.findById(rideId);
  }
}

final rideSavedNoticeControllerProvider = Provider<RideSavedNoticeController>(
  (ref) => RideSavedNoticeController(
    ref.watch(preferencesRepositoryProvider),
    ref.watch(rideRepositoryProvider),
  ),
);

/// The parked ride id; emits when a notification stop parks one.
final pendingRideDetailsProvider = StreamProvider<int?>(
    (ref) => ref.watch(preferencesRepositoryProvider).pendingRideDetails);

/// Shows "Ride saved · Add details" once the app is in front after a ride was
/// stopped from outside it (#75). Waits while the app is in the background —
/// a snack bar there would time out unseen.
class RideSavedNotice extends ConsumerStatefulWidget {
  const RideSavedNotice({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RideSavedNotice> createState() => _RideSavedNoticeState();
}

class _RideSavedNoticeState extends ConsumerState<RideSavedNotice>
    with WidgetsBindingObserver {
  static const _duration = Duration(seconds: 8);

  bool _taking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeShow();
  }

  bool get _inFront {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  }

  Future<void> _maybeShow() async {
    if (_taking || !mounted || !_inFront) return;
    _taking = true;
    try {
      final ride = await ref.read(rideSavedNoticeControllerProvider).take();
      if (ride == null || !mounted) return;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
        content: Text(l10n.rideSavedNotice),
        duration: _duration,
        action: SnackBarAction(
          label: l10n.rideSavedAddDetails,
          onPressed: () {
            if (mounted) showEditRideSheet(context, ref, ride);
          },
        ),
      ));
    } finally {
      _taking = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A stop from the notification shade while the app stays in front.
    ref.listen(pendingRideDetailsProvider, (_, next) {
      if (next.asData?.value != null) _maybeShow();
    });
    return widget.child;
  }
}
