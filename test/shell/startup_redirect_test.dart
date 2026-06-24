import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/features/shell/app_router.dart';
import 'package:retrail/features/shell/routes.dart';

void main() {
  test('onboarding state unknown → splash', () {
    expect(
      resolveRedirect(onboardingDone: null, pendingRide: false, location: '/'),
      AppRoutes.splash,
    );
  });

  test('onboarding not done → init', () {
    expect(
      resolveRedirect(onboardingDone: false, pendingRide: false, location: '/'),
      AppRoutes.init,
    );
  });

  test('not done but already in the init flow → stay', () {
    expect(
      resolveRedirect(
          onboardingDone: false,
          pendingRide: false,
          location: AppRoutes.profilePicture),
      isNull,
    );
  });

  test('done but sitting on splash → main', () {
    expect(
      resolveRedirect(
          onboardingDone: true, pendingRide: false, location: AppRoutes.splash),
      AppRoutes.main,
    );
  });

  test('done on main → stay', () {
    expect(
      resolveRedirect(onboardingDone: true, pendingRide: false, location: '/'),
      isNull,
    );
  });

  test('pending ride deep-link → ride', () {
    expect(
      resolveRedirect(onboardingDone: true, pendingRide: true, location: '/'),
      AppRoutes.ride,
    );
  });

  test('pending ride but already on ride → stay (no loop)', () {
    expect(
      resolveRedirect(
          onboardingDone: true, pendingRide: true, location: AppRoutes.ride),
      isNull,
    );
  });
}
