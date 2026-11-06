import 'dart:io' show Platform;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:vibration/vibration.dart';

/// Speaks and buzzes the pre-ride countdown's last seconds (#81). A platform
/// seam: the countdown drives it through `CountdownCueController`, tests
/// swap in a fake.
abstract interface class CountdownAnnouncer {
  /// Picks the clip set for [locale] before the first cue.
  Future<void> prepare(Locale locale);

  /// One of the last seconds: a short buzz and the number.
  Future<void> count(int second);

  /// The ride starts: a long buzz and the start clip.
  Future<void> go();

  /// Cuts a cue still being played (the countdown was left).
  Future<void> stop();
}

/// Channel to `MainActivity.kt`: `isRingerNormal` (Android only).
const audioChannel = MethodChannel('retrail/audio');

/// Buzz lengths: a tick per second, a longer one when the ride starts.
const _countBuzzMs = 80;
const _goBuzzMs = 400;

/// Bundled clips per language: `audio/countdown/<lang>/<n>.mp3` for 5 to 1
/// and `go.mp3` for the start. Recorded once with a fixed voice (see
/// `assets/audio/countdown/README.md`), so every device plays the same clip.
const _clipFolder = 'audio/countdown';

/// The bundled clips plus vibration. Android plays only with the ringer on:
/// silent and vibrate mode get the buzz alone. iOS can't read its mute switch
/// and plays either way (the `playback` category ignores it); switching the
/// cue off is the setting. Every platform call is best-effort: a missing
/// clip or vibrator never holds up the countdown.
class PlatformCountdownAnnouncer implements CountdownAnnouncer {
  PlatformCountdownAnnouncer({
    AudioPlayer? player,
    this._channel = audioChannel,
    Future<void> Function(int ms)? vibrate,
    bool? isIos,
  }) : _player = player ?? AudioPlayer(),
       _vibrate = vibrate ?? ((ms) => Vibration.vibrate(duration: ms)),
       _isIos = isIos ?? Platform.isIOS;

  final AudioPlayer _player;
  final MethodChannel _channel;
  final Future<void> Function(int ms) _vibrate;
  final bool _isIos;
  String _language = 'en';

  @override
  Future<void> prepare(Locale locale) async {
    _language = locale.languageCode == 'de' ? 'de' : 'en';
    await _quietly(() => _player.setAudioContext(_audioContext));
  }

  @override
  Future<void> count(int second) => _cue('$second', _countBuzzMs);

  @override
  Future<void> go() => _cue('go', _goBuzzMs);

  @override
  Future<void> stop() => _quietly(_player.stop);

  Future<void> _cue(String clip, int buzzMs) async {
    await _quietly(() => _vibrate(buzzMs));
    if (!await _maySpeak()) return;
    await _quietly(
      () => _player.play(AssetSource('$_clipFolder/$_language/$clip.mp3')),
    );
  }

  Future<bool> _maySpeak() async {
    if (_isIos) return true;
    try {
      return await _channel.invokeMethod<bool>('isRingerNormal') ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Ducks other audio (music) while a clip plays, on both platforms.
  /// The `playback` category keeps the clip audible with the mute switch on
  /// and the screen locked (`audio` background mode, see iOS).
  static final _audioContext = AudioContext(
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {
        AVAudioSessionOptions.duckOthers,
        AVAudioSessionOptions.interruptSpokenAudioAndMixWithOthers,
      },
    ),
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.assistanceSonification,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
  );

  static Future<void> _quietly(Future<void> Function() call) async {
    try {
      await call();
    } catch (_) {}
  }
}
