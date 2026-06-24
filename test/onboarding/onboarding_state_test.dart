import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/data_providers.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/domain/activity_type.dart';
import 'package:retrail/features/onboarding/onboarding_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<(ProviderContainer, PreferencesRepository)> setup() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = PreferencesRepository(await SharedPreferences.getInstance());
    final container = ProviderContainer(overrides: [
      preferencesRepositoryProvider.overrideWithValue(prefs),
    ]);
    addTearDown(container.dispose);
    return (container, prefs);
  }

  test('onChange caps the name at 30 characters', () async {
    final (container, _) = await setup();
    final notifier = container.read(nameInputProvider.notifier);
    notifier.onChange('a' * 30);
    expect(container.read(nameInputProvider).length, 30);
    notifier.onChange('a' * 31); // rejected
    expect(container.read(nameInputProvider).length, 30);
  });

  test('saveName trims and skips empty input', () async {
    final (container, prefs) = await setup();
    final controller = container.read(onboardingControllerProvider);

    await controller.saveName(); // empty → default kept
    expect(await prefs.userName.first, 'Retrailer');

    container.read(nameInputProvider.notifier).onChange('  Vali  ');
    await controller.saveName();
    expect(await prefs.userName.first, 'Vali');
  });

  test('finishOnboardingWithActivity saves the type and marks onboarding done',
      () async {
    final (container, prefs) = await setup();
    await container
        .read(onboardingControllerProvider)
        .finishOnboardingWithActivity(ActivityType.scooter);
    expect(await prefs.lastActivityType.first, 'SCOOTER');
    expect(await prefs.onboardingDone.first, true);
  });
}
