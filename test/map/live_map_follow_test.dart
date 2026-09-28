import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('followCameraUpdate', () {
    test('recenter pressed (follow off→on) moves, turns north without heading', () {
      final r = followCameraUpdate(
        wasFollowing: false,
        isFollowing: true,
        hasCurrent: true,
        currentChanged: false, // no new fix needed — recenter acts immediately
      );
      expect(r, isNotNull);
      expect(r!.resetBearing, isTrue);
    });

    test('following + new fix keeps the camera on the rider (keeps bearing)', () {
      final r = followCameraUpdate(
        wasFollowing: true,
        isFollowing: true,
        hasCurrent: true,
        currentChanged: true,
      );
      expect(r, isNotNull);
      expect(r!.resetBearing, isFalse);
    });

    test('not following: a new fix does NOT move (respects the user pan)', () {
      expect(
        followCameraUpdate(
          wasFollowing: false,
          isFollowing: false,
          hasCurrent: true,
          currentChanged: true,
        ),
        isNull,
      );
    });

    test('following but no new fix and not just-recentered → no move', () {
      expect(
        followCameraUpdate(
          wasFollowing: true,
          isFollowing: true,
          hasCurrent: true,
          currentChanged: false,
        ),
        isNull,
      );
    });

    test('no current position → never moves', () {
      expect(
        followCameraUpdate(
          wasFollowing: false,
          isFollowing: true,
          hasCurrent: false,
          currentChanged: false,
        ),
        isNull,
      );
    });

    test('following + first position (none before) → move, turns north without heading', () {
      final r = followCameraUpdate(
        wasFollowing: true,
        isFollowing: true,
        hasCurrent: true,
        hadCurrent: false,
        currentChanged: true,
      );
      expect(r, isNotNull);
      expect(r!.resetBearing, isTrue);
    });
    test('following + first position → instant jump, not an animated fly', () {
      // Flying in from null island, iOS reports the mid-flight (zoomed-out)
      // camera — which the next passive follow would then keep.
      final r = followCameraUpdate(
        wasFollowing: true,
        isFollowing: true,
        hasCurrent: true,
        hadCurrent: false,
        currentChanged: true,
      );
      expect(r!.instant, isTrue);
    });
    test('following + a later fix → animated (instant false)', () {
      final r = followCameraUpdate(
        wasFollowing: true,
        isFollowing: true,
        hasCurrent: true,
        hadCurrent: true,
        currentChanged: true,
      );
      expect(r!.instant, isFalse);
    });
    test('recenter pressed → animated (instant false)', () {
      final r = followCameraUpdate(
        wasFollowing: false,
        isFollowing: true,
        hasCurrent: true,
        hadCurrent: true,
        currentChanged: false,
      );
      expect(r!.instant, isFalse);
    });
    test('not following + first position → no move (respects the pan)', () {
      expect(
        followCameraUpdate(
          wasFollowing: false,
          isFollowing: false,
          hasCurrent: true,
          hadCurrent: false,
          currentChanged: true,
        ),
        isNull,
      );
    });
  });
}
