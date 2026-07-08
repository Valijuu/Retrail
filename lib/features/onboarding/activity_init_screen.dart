import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_shapes.dart';
import '../../domain/activity_type.dart';
import '../../l10n/app_localizations.dart';
import '../shell/routes.dart';
import 'activity_tile.dart';
import 'onboarding_providers.dart';

/// Onboarding step 3 (final): pick the default activity type (Longboard
/// preselected). Continue saves it + finishes onboarding → main shell.
class ActivityInitScreen extends ConsumerStatefulWidget {
  const ActivityInitScreen({super.key});

  @override
  ConsumerState<ActivityInitScreen> createState() => _ActivityInitScreenState();
}

class _ActivityInitScreenState extends ConsumerState<ActivityInitScreen> {
  ActivityType _selected = ActivityType.defaultType;

  Future<void> _finish() async {
    await ref
        .read(onboardingControllerProvider)
        .finishOnboardingWithActivity(_selected);
    if (mounted) context.go(AppRoutes.main);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colors = Theme.of(context).extension<AppColors>()!;
    final text = Theme.of(context).textTheme;
    const types = ActivityType.values;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  children: [
                    const SizedBox(height: 48),
                    Text(l10n.activityPickerTitle,
                        textAlign: TextAlign.center,
                        style: text.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    Text(l10n.initActivityHint,
                        textAlign: TextAlign.center,
                        style: text.bodyLarge
                            ?.copyWith(color: colors.onSurfaceVariant)),
                    const SizedBox(height: 32),
                    GridView(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      // Fixed tile height (not aspect ratio) so every tile is the
                      // same size and fits the longest EN/DE label, regardless of
                      // tile width.
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        mainAxisExtent: 94,
                      ),
                      children: [
                        for (final type in types)
                          ActivityTile(
                            type: type,
                            selected: _selected == type,
                            onTap: () => setState(() => _selected = type),
                          ),
                      ],
                    ),
                    // Inside the scroll content, right under the grid — same
                    // placement as the welcome step's button (which sits under
                    // its input), instead of pinned to the screen bottom.
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        shape:
                            RoundedRectangleBorder(borderRadius: AppShapes.pill),
                      ),
                      child: Text(l10n.actionContinue),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
