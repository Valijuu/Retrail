import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/core/theme/app_theme.dart';
import 'package:retrail/features/profile/profile_avatar.dart';

Widget _wrap(String? path) => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: Scaffold(body: ProfileAvatar(photoPath: path, size: 80)),
);

void main() {
  testWidgets('no photo shows the blank person glyph', (tester) async {
    await tester.pumpWidget(_wrap(null));
    expect(find.byIcon(Icons.person), findsOneWidget);
  });

  // Issue #134: a photo file that cannot be read left an empty (black) circle.
  testWidgets('a photo file that is missing shows the blank avatar', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap('/no/such/dir/profile_photos/1.jpg'));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byIcon(Icons.person), findsOneWidget);
  });
}
