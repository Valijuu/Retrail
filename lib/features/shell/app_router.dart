import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'main_shell.dart';
import 'placeholders.dart';
import 'routes.dart';
import 'startup_provider.dart';

/// Pure redirect logic for the app shell (unit-tested directly):
/// - onboarding state unknown → splash
/// - a pending ride deep-link → /ride
/// - onboarding not done → force the init flow
/// - onboarding done but sitting on splash/init → go to the main shell
String? resolveRedirect({
  required bool? onboardingDone,
  required bool pendingRide,
  required String location,
}) {
  if (onboardingDone == null) return AppRoutes.splash;
  if (pendingRide && location != AppRoutes.ride) return AppRoutes.ride;
  if (!onboardingDone) {
    return location.startsWith(AppRoutes.init) ? null : AppRoutes.init;
  }
  if (location == AppRoutes.splash || location.startsWith(AppRoutes.init)) {
    return AppRoutes.main;
  }
  return null;
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: refresh,
    redirect: (context, state) => resolveRedirect(
      onboardingDone: ref.read(onboardingDoneProvider).asData?.value,
      pendingRide: ref.read(pendingRideDeepLinkProvider),
      location: state.matchedLocation,
    ),
    routes: [
      GoRoute(
          path: AppRoutes.splash,
          pageBuilder: (c, s) => _fade(const RoutePlaceholder('Retrail'), s)),
      GoRoute(
          path: AppRoutes.init,
          pageBuilder: (c, s) => _fade(const RoutePlaceholder('init'), s)),
      GoRoute(
          path: AppRoutes.profilePicture,
          pageBuilder: (c, s) => _fade(const RoutePlaceholder('photo'), s)),
      GoRoute(
          path: AppRoutes.activityPicker,
          pageBuilder: (c, s) => _fade(const RoutePlaceholder('activity'), s)),
      GoRoute(
          path: AppRoutes.main,
          pageBuilder: (c, s) => _fade(const MainShell(), s)),
      GoRoute(
          path: AppRoutes.timer,
          pageBuilder: (c, s) => _fade(const RoutePlaceholder('timer'), s)),
      GoRoute(
          path: AppRoutes.ride,
          pageBuilder: (c, s) => _fade(const RidePlaceholder(), s)),
    ],
  );
});

CustomTransitionPage<void> _fade(Widget child, GoRouterState state) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 180),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      transitionsBuilder: (context, animation, secondary, child) =>
          FadeTransition(opacity: animation, child: child),
    );

/// Re-runs the router's redirect when onboarding state or the deep-link changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(onboardingDoneProvider, (_, _) => notifyListeners());
    ref.listen(pendingRideDeepLinkProvider, (_, _) => notifyListeners());
  }
}
