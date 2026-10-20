import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:vibration/vibration.dart';

import '../l10n/app_localizations.dart';

/// Speaks and buzzes the pre-ride countdown's last seconds (#81). A platform
/// seam: the countdown drives it through `CountdownCueController`, tests
/// swap in a fake.
abstract interface class CountdownAnnouncer {
  /// Readies the voice for [locale] before the first cue.
  Future<void> prepare(Locale locale);

  /// One of the last seconds: a short buzz and the number.
  Future<void> count(int second);

  /// The ride starts: a long buzz and "go".
  Future<void> go();

  /// Cuts a cue still being spoken (the countdown was left).
  Future<void> stop();
}

/// Channel to `MainActivity.kt`: `isRingerNormal` (Android only).
const audioChannel = MethodChannel('retrail/audio');

/// Buzz lengths: a tick per second, a longer one when the ride starts.
const _countBuzzMs = 80;
const _goBuzzMs = 400;

/// The system voice (`flutter_tts`) plus vibration. Android speaks only with
/// the ringer on — silent and vibrate mode get the buzz alone. iOS can't read
/// its mute switch, and speaks with the screen locked (`playback` category +
/// the `audio` background mode), so it speaks either way; switching the cue
/// off is the setting. Every platform call is best-effort: a missing voice or
/// vibrator never holds up the countdown.
class PlatformCountdownAnnouncer implements CountdownAnnouncer {
  PlatformCountdownAnnouncer({
    FlutterTts? tts,
    this._channel = audioChannel,
    Future<void> Function(int ms)? vibrate,
    bool? isIos,
  }) : _tts = tts ?? FlutterTts(),
       _vibrate = vibrate ?? ((ms) => Vibration.vibrate(duration: ms)),
       _isIos = isIos ?? Platform.isIOS;

  final FlutterTts _tts;
  final MethodChannel _channel;
  final Future<void> Function(int ms) _vibrate;
  final bool _isIos;
  String _goPhrase = '';

  @override
  Future<void> prepare(Locale locale) async {
    final voice = _withCopy(locale);
    _goPhrase = lookupAppLocalizations(voice).timerCueGo;
    await _quietly(() async {
      if (_isIos) {
        // Category only — no session activated up front, which would cut
        // the rider's music before the first cue. The synthesizer activates
        // it per phrase (ducking music) and the plugin deactivates it after.
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.duckOthers,
            IosTextToSpeechAudioCategoryOptions
                .interruptSpokenAudioAndMixWithOthers,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.voicePrompt,
        );
      }
      await _tts.setLanguage(_voiceTag(voice));
    });
  }

  @override
  Future<void> count(int second) => _cue('$second', _countBuzzMs);

  @override
  Future<void> go() => _cue(_goPhrase, _goBuzzMs);

  @override
  Future<void> stop() async {
    await _quietly(_tts.stop);
    // A cancelled phrase doesn't release the iOS session the way a finished
    // one does, which would keep music ducked.
    if (_isIos) await _quietly(() => _tts.setSharedInstance(false));
  }

  Future<void> _cue(String phrase, int buzzMs) async {
    await _quietly(() => _vibrate(buzzMs));
    if (!await _maySpeak()) return;
    // focus: Android ducks other audio (music) while the phrase plays.
    await _quietly(() => _tts.speak(phrase, focus: true));
  }

  Future<bool> _maySpeak() async {
    if (_isIos) return true;
    try {
      return await _channel.invokeMethod<bool>('isRingerNormal') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {}
  }
}

/// The app's own language for [locale], or English when the app has no copy
/// for it ("system" on a French phone): the go phrase and the voice must
/// match the copy the app shows.
Locale _withCopy(Locale locale) =>
    locale.languageCode == 'de' || locale.languageCode == 'en'
    ? locale
    : const Locale('en');

/// A full voice tag: iOS needs a region ("de-DE"), the app locale may only
/// carry the language.
String _voiceTag(Locale locale) {
  final country = locale.countryCode;
  if (country != null && country.isNotEmpty) {
    return '${locale.languageCode}-$country';
  }
  return switch (locale.languageCode) {
    'de' => 'de-DE',
    _ => 'en-US',
  };
}
