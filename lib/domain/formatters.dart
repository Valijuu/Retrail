import 'package:intl/intl.dart';

// Note: the date/time formatters below use `intl`'s `DateFormat`. For a non-null
// `locale`, that locale's data must be initialized first via
// `initializeDateFormatting(locale)` — the app does this in `main()`.

/// `DateFormat` construction parses its pattern against the locale's symbol
/// tables — cheap once, but these formatters run per ride card on every
/// build, so a fresh `DateFormat('HH:mm', locale)` etc. per call was
/// measurable build-time cost during a fast History scroll. A `DateFormat`
/// is a pure, stateless formatter for a given (pattern, locale) once built,
/// so instances are safely reused across calls/dates.
final _dateFormatCache = <String, DateFormat>{};
DateFormat _cachedFormat(String pattern, [String? locale]) => _dateFormatCache
    .putIfAbsent('$pattern|$locale', () => DateFormat(pattern, locale));

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
    : _cachedFormat('dd.MM.yyyy  HH:mm', locale)
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

/// `HH:mm`, or `—` when null.
String formatRideTime(int? timestampMs, {String? locale}) => timestampMs == null
    ? '—'
    : _cachedFormat('HH:mm', locale)
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

/// `yyyy-MM-dd` grouping key, or `0000-00-00` when null.
String formatRideDayKey(int? timestampMs) => timestampMs == null
    ? '0000-00-00'
    : _cachedFormat('yyyy-MM-dd')
        .format(DateTime.fromMillisecondsSinceEpoch(timestampMs));

const String _dayKeyPattern = 'yyyy-MM-dd';
const String _localizedDateLabelPattern = 'yMMMMd';

/// Localized day label for history group headers: today/yesterday labels, else
/// a localized `yMMMMd` (e.g. "14. Juni 2026" / "June 14, 2026") — the year is
/// always included so headers stay unambiguous when history spans multiple
/// years; falls back to [dayKey] on parse failure. The UI supplies the
/// localized today/yesterday strings.
String formatDateLabel(
  String dayKey, {
  required String todayLabel,
  required String yesterdayLabel,
  String? locale,
  int? nowMs,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(
      nowMs ?? DateTime.now().millisecondsSinceEpoch);
  final keyFormat = _cachedFormat(_dayKeyPattern);
  final today = keyFormat.format(DateTime(now.year, now.month, now.day));
  final yesterday =
      keyFormat.format(DateTime(now.year, now.month, now.day - 1));

  if (dayKey == today) return todayLabel;
  if (dayKey == yesterday) return yesterdayLabel;
  try {
    final date = keyFormat.parseStrict(dayKey);
    return _cachedFormat(_localizedDateLabelPattern, locale).format(date);
  } catch (_) {
    return dayKey;
  }
}

/// `NumberFormat` pattern tokens: a mandatory digit and the (locale-mapped)
/// decimal separator.
const String _requiredDigit = '0';
const String _patternDecimalSeparator = '.';

/// Same rationale as [_dateFormatCache]: [formatDecimal] runs per ride card on
/// every build, and a built `NumberFormat` is a stateless formatter for its
/// (pattern, locale). A null [locale] is resolved to the current default
/// locale for the key, so a later `Intl.defaultLocale` change isn't masked by
/// a stale cached instance.
final _numberFormatCache = <String, NumberFormat>{};
NumberFormat _cachedNumberFormat(String pattern, String? locale) {
  final resolvedLocale = locale ?? Intl.getCurrentLocale();
  return _numberFormatCache.putIfAbsent(
      '$pattern|$resolvedLocale', () => NumberFormat(pattern, resolvedLocale));
}

/// `NumberFormat` pattern for exactly [decimals] fraction digits, no grouping
/// (e.g. `0`, `0.0`, `0.00`).
String _fixedDecimalsPattern(int decimals) => decimals == 0
    ? _requiredDigit
    : '$_requiredDigit$_patternDecimalSeparator${_requiredDigit * decimals}';

/// [value] with exactly [decimals] fraction digits, in [locale]'s decimal
/// separator.
String formatDecimal(double value, int decimals, {String? locale}) =>
    _cachedNumberFormat(_fixedDecimalsPattern(decimals), locale).format(value);

const double _metresPerKm = 1000;
const int _distanceDecimalPlaces = 2;
const String _kmUnit = 'km';

/// `X.XX km` — converts [metres] to kilometres with two decimal places, using
/// [locale]'s decimal separator (e.g. `1,23 km` in German).
String formatDistanceKm(double metres, {String? locale}) =>
    '${formatDecimal(metres / _metresPerKm, _distanceDecimalPlaces, locale: locale)} $_kmUnit';

/// From this many kilometres on, the short distance drops its fraction digit.
const double _shortDistanceWholeKmThreshold = 10;
const int _shortDistanceDecimalPlaces = 1;
const int _wholeKmDecimalPlaces = 0;

/// Compact distance for the History ride card: `X.X km` under 10 km, whole
/// kilometres (`XX km`) from there on, using [locale]'s decimal separator
/// (e.g. `9,9 km` in German).
String formatShortDistanceKm(double metres, {String? locale}) {
  final km = metres / _metresPerKm;
  final decimals = km < _shortDistanceWholeKmThreshold
      ? _shortDistanceDecimalPlaces
      : _wholeKmDecimalPlaces;
  return '${formatDecimal(km, decimals, locale: locale)} $_kmUnit';
}

const int _speedDecimalPlaces = 1;
const String _speedPlaceholder = '--';
const String _kmhUnit = 'km/h';

/// `X.X km/h` using [locale]'s decimal separator (e.g. `12,3 km/h` in
/// German), or `-- km/h` when [kmh] is null.
String formatSpeedKmh(double? kmh, {String? locale}) {
  final value = kmh == null
      ? _speedPlaceholder
      : formatDecimal(kmh, _speedDecimalPlaces, locale: locale);
  return '$value $_kmhUnit';
}
