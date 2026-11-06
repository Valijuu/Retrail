import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/tracking/countdown_announcer.dart';

class _MockPlayer extends Mock implements AudioPlayer {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockPlayer player;
  late List<int> buzzes;
  bool? ringerNormal;

  setUp(() {
    player = _MockPlayer();
    buzzes = [];
    ringerNormal = true;
    when(() => player.play(any())).thenAnswer((_) async {});
    when(() => player.setAudioContext(any())).thenAnswer((_) async {});
    when(() => player.stop()).thenAnswer((_) async {});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (call) async {
          if (call.method == 'isRingerNormal') return ringerNormal;
          return null;
        });
  });

  setUpAll(() {
    registerFallbackValue(AssetSource('audio/countdown/en/1.mp3'));
    registerFallbackValue(AudioContext());
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);
  });

  PlatformCountdownAnnouncer announcer({bool isIos = false}) =>
      PlatformCountdownAnnouncer(
        player: player,
        vibrate: (ms) async => buzzes.add(ms),
        isIos: isIos,
      );

  String playedClip() {
    final captured = verify(() => player.play(captureAny())).captured;
    return (captured.last as AssetSource).path;
  }

  test('count: a short buzz and the clip for the number', () async {
    final a = announcer();
    await a.prepare(const Locale('en'));
    await a.count(3);
    expect(buzzes, hasLength(1));
    expect(playedClip(), 'audio/countdown/en/3.mp3');
  });

  test('go: a longer buzz and the start clip', () async {
    final a = announcer();
    await a.prepare(const Locale('de'));
    await a.count(1);
    await a.go();
    expect(buzzes.last, greaterThan(buzzes.first));
    expect(playedClip(), 'audio/countdown/de/go.mp3');
  });

  test(
    'clip set follows the app language: de stays de, anything else is en',
    () async {
      await announcer().prepare(const Locale('de'));
      final a = announcer();
      await a.prepare(const Locale('de', 'AT'));
      await a.count(5);
      expect(playedClip(), 'audio/countdown/de/5.mp3');

      final b = announcer();
      await b.prepare(const Locale('fr'));
      await b.count(4);
      expect(playedClip(), 'audio/countdown/en/4.mp3');
    },
  );

  test('prepare sets the ducking audio context once', () async {
    await announcer().prepare(const Locale('en'));
    verify(() => player.setAudioContext(any())).called(1);
  });

  test('Android silent / vibrate ringer: buzz only, no clip', () async {
    ringerNormal = false;
    final a = announcer();
    await a.prepare(const Locale('en'));
    await a.count(5);
    await a.go();
    expect(buzzes, hasLength(2));
    verifyNever(() => player.play(any()));
  });

  test('iOS plays without asking the ringer', () async {
    ringerNormal = false; // ignored on iOS
    final a = announcer(isIos: true);
    await a.prepare(const Locale('en'));
    await a.count(2);
    expect(playedClip(), 'audio/countdown/en/2.mp3');
  });

  test('a failing player never throws into the countdown', () async {
    when(() => player.play(any())).thenThrow(Exception('audio'));
    when(() => player.setAudioContext(any())).thenThrow(Exception('ctx'));
    final a = announcer();
    await a.prepare(const Locale('en'));
    await a.count(4);
    await a.go();
    await a.stop();
    expect(buzzes, hasLength(2));
  });

  test('stop cuts the clip', () async {
    await announcer().stop();
    verify(() => player.stop()).called(1);
  });
}
