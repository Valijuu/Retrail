import 'dart:io';

import '../../data/repositories/preferences_repository.dart';
import 'profile_photo_picker.dart';

/// Deletes a file by path. Injectable so tests don't touch the filesystem.
typedef FileDeleter = Future<void> Function(String path);

/// Coordinates profile-photo files + prefs: add (pick/crop/save), select,
/// delete. Keeps the newest [PreferencesRepository.maxRecentPhotos]
/// photos; evicted/deleted files are removed from disk. Reused by onboarding
/// and Settings.
class ProfilePhotoManager {
  ProfilePhotoManager(this._prefs, this._picker, {FileDeleter? deleteFile})
      : _deleteFile = deleteFile ?? _defaultDelete;

  final PreferencesRepository _prefs;
  final ProfilePhotoPicker _picker;
  final FileDeleter _deleteFile;

  /// Picks a new photo; on success makes it current, prepends it to recents,
  /// and deletes any file evicted past the cap. No-op if cancelled.
  Future<void> addNewPhoto() async {
    final path = await _picker.pickAndCrop();
    if (path == null) return;

    final recent = [..._prefs.recentProfilePhotosNow]..remove(path);
    recent.insert(0, path);
    final kept = recent.take(PreferencesRepository.maxRecentPhotos).toList();
    final evicted = recent.skip(PreferencesRepository.maxRecentPhotos).toList();

    await _prefs.setRecentProfilePhotos(kept);
    await _prefs.setCurrentProfilePhoto(path);
    for (final evictedPath in evicted) {
      await _deleteFile(evictedPath);
    }
  }

  Future<void> select(String path) => _prefs.setCurrentProfilePhoto(path);

  /// Removes a photo from recents and disk; if it was the current one, the
  /// profile photo becomes blank.
  Future<void> delete(String path) async {
    final recent = [..._prefs.recentProfilePhotosNow]..remove(path);
    await _prefs.setRecentProfilePhotos(recent);
    if (_prefs.currentProfilePhotoNow == path) {
      await _prefs.setCurrentProfilePhoto(null);
    }
    await _deleteFile(path);
  }

  static Future<void> _defaultDelete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
