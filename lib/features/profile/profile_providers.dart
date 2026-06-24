import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/data_providers.dart';
import 'image_cropper_photo_picker.dart';
import 'profile_photo_manager.dart';
import 'profile_photo_picker.dart';

/// Real photo picker; override with a fake in tests.
final profilePhotoPickerProvider =
    Provider<ProfilePhotoPicker>((ref) => ImageCropperPhotoPicker());

final profilePhotoManagerProvider = Provider<ProfilePhotoManager>(
  (ref) => ProfilePhotoManager(
    ref.read(preferencesRepositoryProvider),
    ref.read(profilePhotoPickerProvider),
  ),
);

final currentProfilePhotoProvider = StreamProvider<String?>(
  (ref) => ref.watch(preferencesRepositoryProvider).currentProfilePhoto,
);

final recentProfilePhotosProvider = StreamProvider<List<String>>(
  (ref) => ref.watch(preferencesRepositoryProvider).recentProfilePhotos,
);
