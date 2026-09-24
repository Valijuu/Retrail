import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_shapes.dart';
import '../../l10n/app_localizations.dart';
import '../shell/routes.dart';
import 'onboarding_providers.dart';
import '../../core/theme/theme_context.dart';

/// Onboarding step 1: enter a name (optional). Both the primary button and Skip
/// save the trimmed name (if any) and advance to the profile-picture step.
class InitScreen extends ConsumerWidget {
  const InitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final name = ref.watch(nameInputProvider);

    Future<void> next() async {
      await ref.read(onboardingControllerProvider).saveName();
      if (context.mounted) context.go(AppRoutes.profilePicture);
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // The app icon (transparent-background variant) — branding the
              // welcome step for every activity, not just boarders.
              Image.asset('assets/branding/app_icon_foreground.png',
                  width: 132, height: 132),
              const SizedBox(height: 24),
              Text(l10n.initWelcomeTitle,
                  textAlign: TextAlign.center,
                  style: text.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Text(l10n.initNameQuestion,
                  textAlign: TextAlign.center,
                  style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 32),
              TextField(
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onChanged: ref.read(nameInputProvider.notifier).onChange,
                onSubmitted: (_) => next(),
                decoration: InputDecoration(
                  counterText: '',
                  labelText: l10n.initNameLabel,
                  hintText: l10n.initNamePlaceholder,
                  border: OutlineInputBorder(borderRadius: AppShapes.input),
                ),
              ),
              const SizedBox(height: 8),
              Text('${name.length}/30',
                  textAlign: TextAlign.right,
                  style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant)),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: next,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(borderRadius: AppShapes.pill),
                ),
                child: Text(l10n.actionLetsGo),
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
