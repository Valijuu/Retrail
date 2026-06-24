import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesRepository> build() async {
    SharedPreferences.setMockInitialValues({});
    return PreferencesRepository(await SharedPreferences.getInstance());
  }

  test('current profile photo persists and clears', () async {
    final prefs = await build();
    expect(prefs.currentProfilePhotoNow, isNull);

    await prefs.setCurrentProfilePhoto('/a/photo.jpg');
    expect(prefs.currentProfilePhotoNow, '/a/photo.jpg');
    expect(await prefs.currentProfilePhoto.first, '/a/photo.jpg');

    await prefs.setCurrentProfilePhoto(null);
    expect(prefs.currentProfilePhotoNow, isNull);
  });

  test('recent photos round-trip as JSON', () async {
    final prefs = await build();
    expect(prefs.recentProfilePhotosNow, isEmpty);

    await prefs.setRecentProfilePhotos(['/1.jpg', '/2.jpg', '/3.jpg']);
    expect(prefs.recentProfilePhotosNow, ['/1.jpg', '/2.jpg', '/3.jpg']);
    expect(await prefs.recentProfilePhotos.first, ['/1.jpg', '/2.jpg', '/3.jpg']);
  });
}
