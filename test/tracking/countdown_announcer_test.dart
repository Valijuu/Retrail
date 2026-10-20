import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mocktail/mocktail.dart';
import 'package:retrail/tracking/countdown_announcer.dart';

class _MockTts extends Mock implements FlutterTts {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockTts tts;
  late List<int> buzzes;
  bool? ringerNormal;

  setUp(() {
    tts = _MockTts();
    buzzes = [];
    ringerNormal = true;
    when(
      () => tts.speak(any(), focus: any(named: 'focus')),
    ).thenAnswer((_) async => 1);
    when(() => tts.setLanguage(any())).thenAnswer((_) async => 1);
    when(() => tts.setSharedInstance(any())).thenAnswer((_) async => 1);
    when(
      () => tts.setIosAudioCategory(any(), any(), any()),
    ).thenAnswer((_) async => 1);
    when(() => tts.stop()).thenAnswer((_) async => 1);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, (call) async {
          if (call.method == 'isRingerNormal') return ringerNormal;
          return null;
        });
  });

  setUpAll(() {
    registerFallbackValue(IosTextToSpeechAudioCategory.playback);
    registerFallbackValue(IosTextToSpeechAudioMode.voicePrompt);
    registerFallbackValue(<IosTextToSpeechAudioCategoryOptions>[]);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(audioChannel, null);
  });

  PlatformCountdownAnnouncer announcer({bool isIos = false}) =>
      PlatformCountdownAnnouncer(
        tts: tts,
        vibrate: (ms) async => buzzes.add(ms),
        isIos: isIos,
      );

  test('count: a short buzz and the number', () async {
    final a = announcer();
    await a.prepare(const Locale('en'));
    await a.count(3);
    expect(buzzes, hasLength(1));
    verify(() => tts.speak('3', focus: true)).called(1);
  });

  test('go: a longer buzz and the localized phrase', () async {
    final a = announcer();
    await a.prepare(const Locale('de'));
    await a.count(1);
    await a.go();
    expect(buzzes.last, greaterThan(buzzes.first));
    verify(() => tts.speak('Los!', focus: true)).called(1);
  });

  test('prepare picks a regional voice for a bare language', () async {
    await announcer().prepare(const Locale('de'));
    verify(() => tts.setLanguage('de-DE')).called(1);
    await announcer().prepare(const Locale('en', 'GB'));
    verify(() => tts.setLanguage('en-GB')).called(1);
  });

  test('Android silent / vibrate ringer: buzz only, no voice', () async {
    ringerNormal = false;
    final a = announcer();
    await a.prepare(const Locale('en'));
    await a.count(5);
    await a.go();
    expect(buzzes, hasLength(2));
    verifyNever(() => tts.speak(any(), focus: any(named: 'focus')));
  });

  test('iOS speaks without asking the ringer, in the playback category '
      'that ducks music', () async {
    ringerNormal = false; // ignored on iOS
    final a = announcer(isIos: true);
    await a.prepare(const Locale('en'));
    await a.count(2);
    verify(
      () => tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        any(that: contains(IosTextToSpeechAudioCategoryOptions.duckOthers)),
        IosTextToSpeechAudioMode.voicePrompt,
      ),
    ).called(1);
    verify(() => tts.speak('2', focus: true)).called(1);
  });

  test('a failing voice never throws into the countdown', () async {
    when(
      () => tts.speak(any(), focus: any(named: 'focus')),
    ).thenThrow(PlatformException(code: 'tts'));
    when(() => tts.setLanguage(any())).thenThrow(PlatformException(code: 'x'));
    final a = announcer();
    await a.prepare(const Locale('en'));
    await a.count(4);
    await a.go();
    await a.stop();
    expect(buzzes, hasLength(2));
  });

  test('stop cuts the voice', () async {
    await announcer().stop();
    verify(() => tts.stop()).called(1);
  });

  test('iOS: no session activated up front, so music keeps playing until '
      'the first cue', () async {
    await announcer(isIos: true).prepare(const Locale('en'));
    verifyNever(() => tts.setSharedInstance(true));
  });

  test(
    'iOS stop releases the audio session so ducked music comes back',
    () async {
      await announcer(isIos: true).stop();
      verify(() => tts.stop()).called(1);
      verify(() => tts.setSharedInstance(false)).called(1);
    },
  );

  test('an app language without its own copy (fr) falls back to English, '
      'voice included', () async {
    final a = announcer();
    await a.prepare(const Locale('fr', 'FR'));
    await a.go();
    verify(() => tts.setLanguage('en-US')).called(1);
    verify(() => tts.speak('Go!', focus: true)).called(1);
  });
}
