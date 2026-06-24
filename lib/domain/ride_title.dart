import 'package:intl/intl.dart';

import '../data/db/app_database.dart';

/// Display title for a ride: the user's description if non-blank, otherwise a
/// FULL localized date (e.g. "Monday, June 16, 2026" / "Montag, 16. Juni 2026")
/// of `date ?? startTime ?? now` — never empty. Used by UI and search so
/// "skipped" rides (null description) stay findable.
String rideDisplayTitle(Ride ride, {String? locale, int? nowMs}) {
  final description = ride.description;
  if (description != null && description.trim().isNotEmpty) {
    return description;
  }
  final ts = ride.date ??
      ride.startTime ??
      (nowMs ?? DateTime.now().millisecondsSinceEpoch);
  return DateFormat.yMMMMEEEEd(locale)
      .format(DateTime.fromMillisecondsSinceEpoch(ts));
}
