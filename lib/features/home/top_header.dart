import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../profile/profile_avatar.dart';

/// Home header: the greeting (name styled in `primary`) plus a tappable avatar.
class TopHeader extends StatelessWidget {
  const TopHeader({
    super.key,
    required this.greetingTemplate,
    required this.name,
    required this.photoPath,
    this.onAvatarTap,
  });

  /// Greeting text containing a `%s` token where the name goes.
  final String greetingTemplate;
  final String name;
  final String? photoPath;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final base = Theme.of(context)
        .textTheme
        .titleLarge
        ?.copyWith(color: colors.onSurface, fontWeight: FontWeight.w500);
    final parts = greetingTemplate.split('%s');

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: parts.isNotEmpty ? parts[0] : ''),
              TextSpan(
                text: name,
                style: base?.copyWith(
                    color: colors.primary, fontWeight: FontWeight.bold),
              ),
              if (parts.length > 1) TextSpan(text: parts[1]),
            ]),
            style: base,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: onAvatarTap,
          child: ProfileAvatar(photoPath: photoPath, size: 72),
        ),
      ],
    );
  }
}
