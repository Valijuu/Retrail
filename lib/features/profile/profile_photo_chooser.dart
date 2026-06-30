import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../l10n/app_localizations.dart';
import 'profile_providers.dart';

/// Horizontal chooser: an upload slot plus the recent photos (selected = primary
/// ring), each deletable via its corner ✕. Reused by onboarding + Settings.
class ProfilePhotoChooser extends ConsumerWidget {
  const ProfilePhotoChooser({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final l10n = AppLocalizations.of(context);
    final manager = ref.read(profilePhotoManagerProvider);
    final current = ref.watch(currentProfilePhotoProvider).asData?.value;
    final recent = ref.watch(recentProfilePhotosProvider).asData?.value ?? const [];

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Upload slot.
          Semantics(
            button: true,
            label: l10n.profilePictureUploadCd,
            child: GestureDetector(
              onTap: manager.addNewPhoto,
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 12, top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.surfaceContainer,
                  border: Border.all(
                      color: colors.onSurfaceVariant.withValues(alpha: 0.2)),
                ),
                child: Icon(Icons.add_a_photo, color: colors.primary, size: 22),
              ),
            ),
          ),
          for (final path in recent)
            _RecentPhoto(
              path: path,
              selected: path == current,
              colors: colors,
              deleteLabel: l10n.profilePictureDeleteCd,
              onSelect: () => manager.select(path),
              onDelete: () => manager.delete(path),
            ),
        ],
      ),
    );
  }
}

class _RecentPhoto extends StatelessWidget {
  const _RecentPhoto({
    required this.path,
    required this.selected,
    required this.colors,
    required this.deleteLabel,
    required this.onSelect,
    required this.onDelete,
  });

  final String path;
  final bool selected;
  final AppColors colors;
  final String deleteLabel;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12, top: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GestureDetector(
            onTap: onSelect,
            child: SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Dedicated ClipOval (not Container.clipBehavior, which can
                  // leave square corners under Impeller); ring drawn on top.
                  ClipOval(
                    child: Image.file(File(path),
                        fit: BoxFit.cover, width: 64, height: 64),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant.withValues(alpha: 0.2),
                        width: selected ? 3 : 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: -4,
            right: -4,
            child: Semantics(
              button: true,
              label: deleteLabel,
              child: GestureDetector(
                onTap: onDelete,
                child: CircleAvatar(
                  radius: 10,
                  backgroundColor: colors.deleteActionBg,
                  child: Icon(Icons.close, size: 12, color: colors.deleteActionText),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
