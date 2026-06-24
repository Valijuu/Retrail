import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../l10n/app_localizations.dart';
import '../profile/profile_avatar.dart';
import '../profile/profile_photo_chooser.dart';
import '../profile/profile_providers.dart';
import '../shell/routes.dart';
import 'onboarding_providers.dart';

/// Onboarding step 2 (optional): set a profile photo, or keep it blank. The
/// last 5 photos are selectable + deletable. Continue/Skip → activity picker.
class ProfilePictureScreen extends ConsumerWidget {
  const ProfilePictureScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    final name = ref.watch(nameInputProvider).trim();
    final current = ref.watch(currentProfilePhotoProvider).asData?.value;

    void next() => context.go(AppRoutes.activityPicker);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                name.isNotEmpty
                    ? l10n.profilePictureGreetingNamed(name)
                    : l10n.profilePictureGreetingAnon,
                textAlign: TextAlign.center,
                style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Text(l10n.profilePictureSubtitle,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 32),
              Center(child: ProfileAvatar(photoPath: current)),
              const SizedBox(height: 28),
              const ProfilePhotoChooser(),
              const Spacer(),
              FilledButton(
                onPressed: next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: AppShapes.pill),
                ),
                child: Text(l10n.actionContinue),
              ),
              const SizedBox(height: 8),
              TextButton(onPressed: next, child: Text(l10n.actionSkip)),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
