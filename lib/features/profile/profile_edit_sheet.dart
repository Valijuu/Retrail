import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../data/repositories/data_providers.dart';
import '../../l10n/app_localizations.dart';
import 'profile_avatar.dart';
import 'profile_photo_chooser.dart';
import 'profile_providers.dart';

const _nameMaxLength = 30;

/// Bottom-sheet to edit the profile name + photo. Reuses [ProfileAvatar] +
/// [ProfilePhotoChooser] (photo persists live via the manager); Save writes the
/// name. Ports `ProfileEditSheet` to the Flutter port's photo model.
class ProfileEditSheet extends ConsumerStatefulWidget {
  const ProfileEditSheet({super.key});

  @override
  ConsumerState<ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends ConsumerState<ProfileEditSheet> {
  late final TextEditingController _name = TextEditingController(
      text: ref.read(preferencesRepositoryProvider).userNameNow);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isNotEmpty) {
      ref.read(preferencesRepositoryProvider).saveUserName(name);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    final current = ref.watch(currentProfilePhotoProvider).asData?.value;

    return SafeArea(
      child: SingleChildScrollView(
        // Lift the sheet above the keyboard (viewInsets) so the name field
        // stays visible while typing — without this the keyboard covered it.
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 20),
              child: Text(l10n.profileEditTitle,
                  style: text.titleLarge?.copyWith(color: colors.onSurface)),
            ),
            // Name field.
            Container(
              decoration: BoxDecoration(
                  color: colors.surfaceContainer, borderRadius: AppShapes.card),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.initNameLabel,
                      style:
                          text.labelSmall?.copyWith(color: colors.primary)),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _name,
                    maxLength: _nameMaxLength,
                    cursorColor: colors.primary,
                    style: text.bodyLarge?.copyWith(color: colors.onSurface),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      counterText: '',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Center(child: ProfileAvatar(photoPath: current, size: 96)),
            const SizedBox(height: 16),
            const ProfilePhotoChooser(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _Pill(
                    label: l10n.actionCancel,
                    bg: colors.surfaceContainer,
                    fg: colors.onSurfaceVariant,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _Pill(
                    label: l10n.actionSave,
                    bg: colors.primary,
                    fg: colors.onPrimary,
                    onTap: _save,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(
      {required this.label,
      required this.bg,
      required this.fg,
      required this.onTap});
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: const RoundedRectangleBorder(borderRadius: AppShapes.pill),
        ),
        child: Text(label,
            maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w500)),
      ),
    );
  }
}
