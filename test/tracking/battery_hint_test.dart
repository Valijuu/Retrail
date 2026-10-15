import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/tracking/battery_optimization.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeBattery implements BatteryOptimizationService {
  _FakeBattery({required this.restricted});
  final bool restricted;

  @override
  Future<bool> isRestricted() async => restricted;
}

void main() {
  Future<ProviderContainer> container({
    required bool restricted,
    Map<String, Object> prefs = const {},
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    final repo = PreferencesRepository(await SharedPreferences.getInstance());
    final c = ProviderContainer(
      overrides: [
        preferencesRepositoryProvider.overrideWithValue(repo),
        batteryOptimizationServiceProvider.overrideWithValue(
          _FakeBattery(restricted: restricted),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('shows the hint while Android may stop the recording', () async {
    final c = await container(restricted: true);
    expect(await c.read(batteryHintProvider).shouldShow(), isTrue);
  });

  test('no hint once the app is exempt from battery optimization', () async {
    final c = await container(restricted: false);
    expect(await c.read(batteryHintProvider).shouldShow(), isFalse);
  });

  test('"Not now" is remembered: the hint never shows again', () async {
    final c = await container(restricted: true);
    await c.read(batteryHintProvider).dismiss();
    expect(await c.read(batteryHintProvider).shouldShow(), isFalse);
    expect(
      c.read(preferencesRepositoryProvider).batteryHintDismissedNow,
      isTrue,
    );
  });

  test('a dismissal from an earlier launch still holds', () async {
    final c = await container(
      restricted: true,
      prefs: {'battery_hint_dismissed': true},
    );
    expect(await c.read(batteryHintProvider).shouldShow(), isFalse);
  });
}
