import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../active_ride/active_ride_screen.dart';
import '../onboarding/activity_init_screen.dart';
import '../onboarding/init_screen.dart';
import '../onboarding/profile_picture_screen.dart';
import '../timer/countdown_screen.dart';
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
      // Onboarding steps nest (name → photo → activity) so `go` to a later
      // step stacks the earlier ones beneath it: system back steps back one
      // screen instead of closing the app mid-onboarding (issue #32).
      GoRoute(
        path: AppRoutes.init,
        pageBuilder: (c, s) => _fade(const InitScreen(), s),
        routes: [
          GoRoute(
            path: 'photo',
            pageBuilder: (c, s) => _fade(const ProfilePictureScreen(), s),
            routes: [
              GoRoute(
                  path: 'activity',
                  pageBuilder: (c, s) => _fade(const ActivityInitScreen(), s)),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.main,
        pageBuilder: (c, s) => _fade(const MainShell(), s),
        // Timer + ride are CHILD routes so the shell stays alive underneath:
        // leaving the ride pops back to the still-mounted MainShell instead of
        // cold-rebuilding it (which flashed a dark half-built frame that looked
        // like the timer page) — and the timer is never in the stack while on
        // /ride, so it cannot reappear during the exit transition.
        routes: [
          GoRoute(
              path: 'timer',
              pageBuilder: (c, s) => _fade(const CountdownScreen(), s)),
          GoRoute(
              path: 'ride',
              pageBuilder: (c, s) => _rideEnter(const ActiveRideScreen(), s)),
        ],
      ),
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

/// A softer entrance for the ride screen: a longer, eased fade with a subtle
/// scale-up so the map+stats layout glides in instead of cutting in abruptly.
/// During this animation the live map is still masked by its terrain
/// placeholder, so only plain widgets transform (no native-view quirks); the
/// map then fades in once its style loads.
CustomTransitionPage<void> _rideEnter(Widget child, GoRouterState state) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 340),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      transitionsBuilder: (context, animation, secondary, child) {
        final eased =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: eased,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(eased),
            child: child,
          ),
        );
      },
    );

/// Re-runs the router's redirect when onboarding state or the deep-link changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(onboardingDoneProvider, (_, _) => notifyListeners());
    ref.listen(pendingRideDeepLinkProvider, (_, _) => notifyListeners());
  }
}
