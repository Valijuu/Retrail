import 'package:intl/intl.dart';

import '../data/db/app_database.dart';

/// Reused across calls — `DateFormat` construction parses the pattern against
/// the locale's symbol tables, so a fresh instance per call is wasted work
/// when this runs on every build of an undescribed ride's card.
final _titleDateFormats = <String?, DateFormat>{};
DateFormat _titleDateFormat(String? locale) =>
    _titleDateFormats.putIfAbsent(locale, () => DateFormat.yMMMMEEEEd(locale));

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
  return _titleDateFormat(locale)
      .format(DateTime.fromMillisecondsSinceEpoch(ts));
}
