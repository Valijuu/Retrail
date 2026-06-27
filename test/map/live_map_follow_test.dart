import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/map/live_map.dart';

void main() {
  group('followCameraUpdate', () {
    test('recenter pressed (follow off→on) moves and restores zoom', () {
      final r = followCameraUpdate(
        wasFollowing: false,
        isFollowing: true,
        hasCurrent: true,
        currentChanged: false, // no new fix needed — recenter acts immediately
      );
      expect(r, isNotNull);
      expect(r!.resetZoom, isTrue);
    });

    test('following + new fix keeps the camera on the rider (current zoom)', () {
      final r = followCameraUpdate(
        wasFollowing: true,
        isFollowing: true,
        hasCurrent: true,
        currentChanged: true,
      );
      expect(r, isNotNull);
      expect(r!.resetZoom, isFalse);
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
  });
}
