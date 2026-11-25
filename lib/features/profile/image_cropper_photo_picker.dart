import 'dart:io';

import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'profile_photo_picker.dart';

/// Real [ProfilePhotoPicker]: gallery pick → 1:1 crop (512², q85) → saved to the
/// app documents dir under `profile_photos/`. Device-verified (not unit-tested).
class ImageCropperPhotoPicker implements ProfilePhotoPicker {
  @override
  Future<String?> pickAndCrop() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return null;

    // The picker's and the cropper's temp files are never needed again once the
    // result is copied (or the crop failed or was cancelled) (#145).
    String? croppedPath;
    try {
      return await _cropAndSave(picked.path, (path) => croppedPath = path);
    } finally {
      await _deleteQuietly(picked.path);
      final temp = croppedPath;
      if (temp != null) await _deleteQuietly(temp);
    }
  }

  Future<String?> _cropAndSave(
    String sourcePath,
    void Function(String path) onCropped,
  ) async {
    final cropped = await ImageCropper().cropImage(
      sourcePath: sourcePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      maxWidth: 512,
      maxHeight: 512,
      compressQuality: 85,
      // Circular crop overlay (locked 1:1) so the picked photo matches the round
      // avatar shown on Home; the saved file is still a 512² square the avatar
      // clips to a circle.
      uiSettings: [
        AndroidUiSettings(
          cropStyle: CropStyle.circle,
          lockAspectRatio: true,
          hideBottomControls: true,
        ),
        IOSUiSettings(
          cropStyle: CropStyle.circle,
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
        ),
      ],
    );
    if (cropped == null) return null;
    onCropped(cropped.path);

    final dir = await getApplicationDocumentsDirectory();
    final dest = File(
      p.join(
        dir.path,
        'profile_photos',
        '${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    );
    await dest.parent.create(recursive: true);
    await File(cropped.path).copy(dest.path);
    return dest.path;
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // A leftover temp file is harmless; never fail the pick over it.
    }
  }
}
