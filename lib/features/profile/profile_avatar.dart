import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Circular profile picture: shows [photoPath] if set, else a neutral blank
/// placeholder (person glyph). Reused by onboarding, Home header, Settings.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.photoPath,
    this.size = 140,
    this.ring = true,
  });

  final String? photoPath;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colors.surfaceContainer,
        border: ring ? Border.all(color: colors.primary, width: 3) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: photoPath != null
          ? Image.file(File(photoPath!), fit: BoxFit.cover)
          : Icon(Icons.person, size: size * 0.5, color: colors.subtleText),
    );
  }
}
