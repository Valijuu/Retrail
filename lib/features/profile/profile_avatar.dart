import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/theme/theme_context.dart';

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
    final colors = context.colors;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Clip the photo to a circle with a dedicated ClipOval — more reliable
          // than Container.clipBehavior + BoxShape.circle, which can fail to clip
          // the image (square corners poke past the ring) under Impeller.
          ClipOval(
            child: photoPath != null
                ? Image.file(File(photoPath!),
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    // Decode at display size — the cropped photo can be far
                    // larger than this avatar, and a full-resolution decode +
                    // GPU upload visibly janks the first Home build.
                    cacheWidth:
                        (size * MediaQuery.devicePixelRatioOf(context)).round())
                : Container(
                    color: colors.surfaceContainer,
                    alignment: Alignment.center,
                    child: Icon(Icons.person,
                        size: size * 0.5, color: colors.subtleText),
                  ),
          ),
          // Ring drawn on top so it never insets/shrinks the photo.
          if (ring)
            DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: colors.primary, width: 3),
              ),
            ),
        ],
      ),
    );
  }
}
