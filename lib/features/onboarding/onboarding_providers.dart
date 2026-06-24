import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import '../../domain/activity_type.dart';

/// The name being entered during onboarding. Caps input at 30 characters
/// (mirrors `InitViewModel.onNameChange`).
class NameInputNotifier extends Notifier<String> {
  @override
  String build() => '';

  void onChange(String name) {
    if (name.length <= 30) state = name;
  }
}

final nameInputProvider =
    NotifierProvider<NameInputNotifier, String>(NameInputNotifier.new);

/// Onboarding actions, ported from `InitViewModel`.
class OnboardingController {
  OnboardingController(this._ref);

  final Ref _ref;

  /// Saves the trimmed name, skipping empty input.
  Future<void> saveName() async {
    final name = _ref.read(nameInputProvider).trim();
    if (name.isNotEmpty) {
      await _ref.read(preferencesRepositoryProvider).saveUserName(name);
    }
  }

  /// Final onboarding step: persists the default activity and marks onboarding
  /// done so the next launch lands on the main shell.
  Future<void> finishOnboardingWithActivity(ActivityType type) async {
    final prefs = _ref.read(preferencesRepositoryProvider);
    await prefs.saveLastActivityType(type.id);
    await prefs.setOnboardingDone();
  }
}

final onboardingControllerProvider =
    Provider<OnboardingController>(OnboardingController.new);
