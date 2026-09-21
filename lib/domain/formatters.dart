import 'package:intl/intl.dart';

// Note: the date/time formatters below use `intl`'s `DateFormat`. For a non-null
// `locale`, that locale's data must be initialized first via
// `initializeDateFormatting(locale)` — the app does this in `main()`.

/// Formats a duration in milliseconds as `H:MM:SS` (≥ 1h) or `MM:SS`.
String formatDuration(int durationMs) => _hms(durationMs ~/ 1000);

/// Formats an elapsed duration in seconds as `H:MM:SS` (≥ 1h) or `MM:SS`.
String formatElapsed(int seconds) => _hms(seconds);

String _hms(int totalSeconds) {
  final h = totalSeconds ~/ 3600;
  final m = (totalSeconds % 3600) ~/ 60;
  final s = totalSeconds % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

/// `dd.MM.yyyy  HH:mm` (two spaces), or `—` when null.
String formatRideDate(int? timestampMs, {String? locale}) => timestampMs == null
    ? '—'
    : DateFormat('dd.MM.yyyy  HH:mm', locale)
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

/// `HH:mm`, or `—` when null.
String formatRideTime(int? timestampMs, {String? locale}) => timestampMs == null
    ? '—'
    : DateFormat('HH:mm', locale)
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

/// `yyyy-MM-dd` grouping key, or `0000-00-00` when null.
String formatRideDayKey(int? timestampMs) => timestampMs == null
    ? '0000-00-00'
    : DateFormat('yyyy-MM-dd')
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

/// Localized day label for history group headers: today/yesterday labels, else
/// a localized `MMMMd` (e.g. "14. Juni" / "June 14"); falls back to [dayKey] on
/// parse failure. The UI supplies the localized today/yesterday strings.
String formatDateLabel(
  String dayKey, {
  required String todayLabel,
  required String yesterdayLabel,
  String? locale,
  int? nowMs,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(
      nowMs ?? DateTime.now().millisecondsSinceEpoch);
  final keyFormat = DateFormat('yyyy-MM-dd');
  final today = keyFormat.format(DateTime(now.year, now.month, now.day));
  final yesterday =
      keyFormat.format(DateTime(now.year, now.month, now.day - 1));

  if (dayKey == today) return todayLabel;
  if (dayKey == yesterday) return yesterdayLabel;
  try {
    final date = keyFormat.parseStrict(dayKey);
    return DateFormat('MMMMd', locale).format(date);
  } catch (_) {
    return dayKey;
  }
}

const int _speedDecimalPlaces = 1;
const String _speedPlaceholder = '--';
const String _kmhUnit = 'km/h';

/// `X.X km/h`, or `-- km/h` when [kmh] is null.
String formatSpeedKmh(double? kmh) {
  final value = kmh == null
      ? _speedPlaceholder
      : kmh.toStringAsFixed(_speedDecimalPlaces);
  return '$value $_kmhUnit';
}
