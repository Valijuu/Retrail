import 'package:flutter_test/flutter_test.dart';
import 'package:retrail/data/repositories/preferences_repository.dart';
import 'package:retrail/features/profile/profile_photo_manager.dart';
import 'package:retrail/features/profile/profile_photo_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakePicker implements ProfilePhotoPicker {
  _FakePicker(this.paths);
  final List<String?> paths;
  int _i = 0;
  @override
  Future<String?> pickAndCrop() async =>
      _i < paths.length ? paths[_i++] : null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<PreferencesRepository> prefs() async {
    SharedPreferences.setMockInitialValues({});
    return PreferencesRepository(await SharedPreferences.getInstance());
  }

  test('addNewPhoto sets current and prepends to recents', () async {
    final p = await prefs();
    final m = ProfilePhotoManager(p, _FakePicker(['/1.jpg', '/2.jpg']),
        deleteFile: (_) async {});
    await m.addNewPhoto();
    await m.addNewPhoto();
    expect(p.currentProfilePhotoNow, '/2.jpg');
    expect(p.recentProfilePhotosNow, ['/2.jpg', '/1.jpg']);
  });

  test('a 6th photo evicts and deletes the oldest', () async {
    final p = await prefs();
    final deleted = <String>[];
    final m = ProfilePhotoManager(
      p,
      _FakePicker(['/1.jpg', '/2.jpg', '/3.jpg', '/4.jpg', '/5.jpg', '/6.jpg']),
      deleteFile: (path) async => deleted.add(path),
    );
    for (var i = 0; i < 6; i++) {
      await m.addNewPhoto();
    }
    expect(p.recentProfilePhotosNow,
        ['/6.jpg', '/5.jpg', '/4.jpg', '/3.jpg', '/2.jpg']);
    expect(deleted, ['/1.jpg']);
  });

  test('select changes the current photo', () async {
    final p = await prefs();
    final m = ProfilePhotoManager(p, _FakePicker(['/1.jpg', '/2.jpg']),
        deleteFile: (_) async {});
    await m.addNewPhoto();
    await m.addNewPhoto();
    await m.select('/1.jpg');
    expect(p.currentProfilePhotoNow, '/1.jpg');
  });

  test('delete removes from recents, deletes the file, clears current if selected',
      () async {
    final p = await prefs();
    final deleted = <String>[];
    final m = ProfilePhotoManager(p, _FakePicker(['/1.jpg']),
        deleteFile: (path) async => deleted.add(path));
    await m.addNewPhoto(); // current = /1.jpg
    await m.delete('/1.jpg');
    expect(p.recentProfilePhotosNow, isEmpty);
    expect(p.currentProfilePhotoNow, isNull);
    expect(deleted, ['/1.jpg']);
  });

  test('cancelled pick is a no-op', () async {
    final p = await prefs();
    final m = ProfilePhotoManager(p, _FakePicker([null]), deleteFile: (_) async {});
    await m.addNewPhoto();
    expect(p.currentProfilePhotoNow, isNull);
    expect(p.recentProfilePhotosNow, isEmpty);
  });
}
